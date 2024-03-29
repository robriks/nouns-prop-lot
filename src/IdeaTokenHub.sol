// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "./interfaces/IIdeaTokenHub.sol";
import {IPropLot} from "./interfaces/IPropLot.sol";
import {PropLot} from "./PropLot.sol";
import {console2} from "forge-std/console2.sol"; //todo delete

/// @title PropLot Protocol IdeaTokenHub
/// @author 📯📯📯.eth
/// @notice The PropLot Protocol Idea Token Hub extends the Nouns governance ecosystem by tokenizing and crowdfunding ideas
/// for Nouns governance proposals. Nouns NFT holders earn yield in exchange for lending their tokens' proposal power to PropLot,
/// which democratizes access and lowers the barrier of entry for anyone with a worthy idea, represented as an ERC1155 tokenId.
/// Use of ERC1155 enables permissionless onchain minting with competition introduced by a crowdfunding auction.
/// Each `tokenId` represents a proposal idea which can be individually funded via permissionless mint. At the conclusion
/// of each auction, the winning tokenized ideas (with the most funding) are officially proposed into the Nouns governance system
/// via the use of lent Nouns proposal power, provided by token holders who have delegated to the protocol.

contract IdeaTokenHub is ERC1155, IIdeaTokenHub {
    /*
      Constants
    */

    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public constant minSponsorshipAmount = 0.0001 ether;
    uint256 public constant decimals = 18;
    /// @dev The length of time for a wave in blocks, marking the block number where winning ideas are chosen
    uint256 public immutable waveLength = 1209600;

    IPropLot private immutable __propLotCore;
    INounsDAOLogicV3 private immutable __nounsGovernor;

    /*
      Storage
    */

    WaveInfo public currentWaveInfo;
    uint96 private _nextIdeaId;

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    mapping(uint96 => IdeaInfo) internal ideaInfos;
    mapping(address => mapping(uint96 => SponsorshipParams)) internal sponsorships;
    mapping(address => uint256) internal claimableYield;

    /*
      IdeaTokenHub
    */

    constructor(INounsDAOLogicV3 nounsGovernor_, string memory uri_) ERC1155(uri_) {
        __propLotCore = IPropLot(msg.sender);
        __nounsGovernor = nounsGovernor_;

        ++currentWaveInfo.currentWave;
        currentWaveInfo.startBlock = uint32(block.number);
        ++_nextIdeaId;
    }

    /// @inheritdoc IIdeaTokenHub
    function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description)
        public
        payable
        returns (uint96 newIdeaId)
    {
        _validateIdeaCreation(ideaTxs, description);

        // cache in memory to save on SLOADs
        newIdeaId = _nextIdeaId;
        uint216 value = uint216(msg.value);
        IPropLot.Proposal memory proposal = IPropLot.Proposal(ideaTxs, description);
        IdeaInfo memory ideaInfo = IdeaInfo(value, uint32(block.number), false, proposal);
        ideaInfos[newIdeaId] = ideaInfo;
        ++_nextIdeaId;

        sponsorships[msg.sender][newIdeaId].contributedBalance = value;
        sponsorships[msg.sender][newIdeaId].isCreator = true;

        _mint(msg.sender, newIdeaId, msg.value, "");

        emit IdeaCreated(IPropLot.Proposal(ideaTxs, description), msg.sender, newIdeaId, SponsorshipParams(value, true));
    }

    /// @inheritdoc IIdeaTokenHub
    function sponsorIdea(uint256 ideaId) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        // revert if a new wave should be started
        if (block.number - waveLength >= currentWaveInfo.startBlock) revert WaveIncomplete();

        // typecast values can contain all Ether in existence && quintillions of ideas per human on earth
        uint216 value = uint216(msg.value);
        uint96 id = uint96(ideaId);
        if (ideaInfos[id].isProposed) revert AlreadyProposed(ideaId);

        ideaInfos[id].totalFunding += value;
        // `isCreator` for caller remains the same as at creation
        sponsorships[msg.sender][id].contributedBalance += value;

        SponsorshipParams storage params = sponsorships[msg.sender][id];

        _mint(msg.sender, ideaId, msg.value, "");

        emit Sponsorship(msg.sender, id, params);
    }

    /// @inheritdoc IIdeaTokenHub
    function finalizeWave()
        external
        returns (
            IPropLot.Delegation[] memory delegations,
            uint96[] memory winningIds,
            uint256[] memory nounsProposalIds
        )
    {
        // check that waveLength has passed
        if (block.number - waveLength < currentWaveInfo.startBlock) revert WaveIncomplete();
        ++currentWaveInfo.currentWave;
        currentWaveInfo.startBlock = uint32(block.number);

        // identify number of proposals to push for current voting threshold
        (uint256 minRequiredVotes, uint256 numEligibleProposers) = __propLotCore.numEligibleProposerDelegates();
        // terminate early when there is not enough liquidity for proposals to be made
        if (numEligibleProposers == 0) return (new IPropLot.Delegation[](0), new uint96[](0), new uint256[](0));
        // determine winners from ordered list if there are any
        winningIds = getOrderedEligibleIdeaIds(numEligibleProposers);

        // populate array with winning txs & description and aggregate total payout amount
        uint256 winningProposalsTotalFunding;
        IPropLot.Proposal[] memory winningProposals = new IPropLot.Proposal[](winningIds.length);
        for (uint256 l; l < winningIds.length; ++l) {
            uint96 currentWinnerId = winningIds[l];
            // if there are more eligible proposers than ideas, rightmost `winningIds` will be 0 which is an invalid `ideaId` value
            if (currentWinnerId == 0) break;

            IdeaInfo storage winner = ideaInfos[currentWinnerId];
            winner.isProposed = true;
            winningProposalsTotalFunding += winner.totalFunding;
            winningProposals[l] = winner.proposal;
        }

        (delegations, nounsProposalIds) = __propLotCore.pushProposals(winningProposals);

        // calculate yield for returned valid delegations
        for (uint256 m; m < delegations.length; ++m) {
            uint256 denominator = 10_000 * minRequiredVotes / delegations[m].votingPower;
            uint256 yield = (winningProposalsTotalFunding / delegations.length) / denominator / 10_000;

            // enable claiming of yield calculated as total revenue split between all delegations, proportional to delegated voting power
            address currentDelegator = delegations[m].delegator;
            claimableYield[currentDelegator] += yield;
        }
    }

    /// @inheritdoc IIdeaTokenHub
    function claim() external returns (uint256 claimAmt) {
        claimAmt = claimableYield[msg.sender];
        delete claimableYield[msg.sender];

        (bool r,) = msg.sender.call{value: claimAmt}("");
        if (!r) revert ClaimFailure();
    }

    /*
      Views
    */

    /// @inheritdoc IIdeaTokenHub
    /// @notice The returned array treats ineligible IDs (ie already proposed) as 0 values at the array end.
    /// Since 0 is an invalid `ideaId` value, these are simply filtered out when invoked within `finalizeWave()`
    function getOrderedEligibleIdeaIds(uint256 optLimiter) public view returns (uint96[] memory orderedEligibleIds) {
        // cache in memory to reduce SLOADs
        uint256 nextIdeaId = getNextIdeaId();
        uint256 len;
        if (optLimiter == 0 || optLimiter >= nextIdeaId) {
            // there cannot be more winners than existing `ideaIds`
            len = nextIdeaId - 1;
        } else {
            len = optLimiter;
        }

        orderedEligibleIds = new uint96[](len);
        for (uint96 i = 1; i < nextIdeaId; ++i) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[i];
            // skip previous winners
            if (currentIdeaInfo.isProposed) {
                continue;
            }

            // compare `totalFunding` and push winners into array, ordering by highest funding
            for (uint256 j; j < len; ++j) {
                IdeaInfo storage currentWinner = ideaInfos[orderedEligibleIds[j]];
                // if a tokenId with higher funding is found, reorder array from right to left and then insert it
                if (currentIdeaInfo.totalFunding > currentWinner.totalFunding) {
                    for (uint256 k = len - 1; k > j; --k) {
                        orderedEligibleIds[k] = orderedEligibleIds[k - 1];
                    }

                    orderedEligibleIds[j] = i; // i represents top level loop's `ideaId`
                    break;
                }
            }
        }
    }

    /// @inheritdoc IIdeaTokenHub
    function getOrderedProposedIdeaIds() public view returns (uint96[] memory orderedProposedIds) {
        // cache in memory to reduce SLOADs
        uint256 nextIdeaId = getNextIdeaId();
        uint256 len;

        // get length of proposed ideas array
        for (uint96 i = 1; i < nextIdeaId; ++i) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[i];
            // skip previous winners
            if (currentIdeaInfo.isProposed) {
                len++;
            }
        }

        // populate array
        uint256 index;
        orderedProposedIds = new uint96[](len);
        for (uint96 j = 1; j < nextIdeaId; ++j) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[j];
            if (currentIdeaInfo.isProposed) {
                orderedProposedIds[index] = j;
                index++;
            }
        }
    }

    function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return ideaInfos[uint96(ideaId)];
    }

    function getSponsorshipInfo(address sponsor, uint256 ideaId) public view returns (SponsorshipParams memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return sponsorships[sponsor][uint96(ideaId)];
    }

    function getClaimableYield(address nounder) external view returns (uint256) {
        return claimableYield[nounder];
    }

    function getNextIdeaId() public view returns (uint256) {
        return uint256(_nextIdeaId);
    }

    /*
      Internals
    */

    function _validateIdeaCreation(NounsDAOV3Proposals.ProposalTxs calldata _ideaTxs, string calldata _description)
        internal
    {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);

        // To account for Nouns governor contract upgradeability, `PROPOSAL_MAX_OPERATIONS` must be read dynamically
        uint256 maxOperations = __nounsGovernor.proposalMaxOperations();
        if (_ideaTxs.targets.length == 0 || _ideaTxs.targets.length > maxOperations) {
            revert InvalidActionsCount(_ideaTxs.targets.length);
        }

        if (
            _ideaTxs.targets.length != _ideaTxs.values.length || _ideaTxs.targets.length != _ideaTxs.signatures.length
                || _ideaTxs.targets.length != _ideaTxs.calldatas.length
        ) revert ProposalInfoArityMismatch();

        if (keccak256(bytes(_description)) == keccak256("")) revert InvalidDescription();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (from != address(0x0) && to != address(0x0)) revert Soulbound();
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
