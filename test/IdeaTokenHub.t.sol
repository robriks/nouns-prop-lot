// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLotTest} from "test/PropLot.t.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract IdeaTokenHubTest is NounsEnvSetup, TestUtils {

    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    uint256 roundLength;
    uint256 minSponsorshipAmount;
    uint256 decimals;
    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    // singular proposal stored for easier referencing against `IdeaInfo` struct member
    IPropLot.Proposal proposal;
    IdeaTokenHub.RoundInfo firstRoundInfo; // only used for sanity checks
    
    function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();

        // setup PropLot contracts
        roundLength = 1209600;//todo
        minSponsorshipAmount = 0.001 ether;
        decimals = 18;
        uri = 'someURI';
        // roll to block number of at least `roundLength` to prevent underflow within `currentRoundInfo.startBlock`
        vm.roll(roundLength);
        propLot = new PropLotHarness(INounsDAOLogicV3(address(nounsGovernorProxy)), IERC721Checkpointable(address(nounsTokenHarness)), uri);
        ideaTokenHub = IdeaTokenHub(propLot.ideaTokenHub());

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push('');
        txs.calldatas.push('');
        description = 'test';

        // provide funds for `txs` value
        vm.deal(address(this), 1 ether);

        // continue with IdeaTokenHub configuration
        firstRoundInfo.currentRound = 1;
        firstRoundInfo.startBlock = uint32(block.number);
        proposal = IPropLot.Proposal(txs, description);
    }

    function test_setUp() public {
        // sanity checks
        assertEq(ideaTokenHub.roundLength(), roundLength);
        assertEq(ideaTokenHub.minSponsorshipAmount(), minSponsorshipAmount);
        assertEq(ideaTokenHub.decimals(), decimals);

        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        (uint32 currentRound, uint32 startBlock) = ideaTokenHub.currentRoundInfo();
        assertEq(currentRound, firstRoundInfo.currentRound);
        assertEq(startBlock, firstRoundInfo.startBlock);

        bytes memory err = abi.encodeWithSelector(IdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);
    }

    function test_createIdeaEOA(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, 0.001 ether, type(uint64).max));
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        for (uint256 i; i < numCreators; ++i) {
            address nounder = _createNounderEOA(i);
            vm.deal(nounder, ideaValue);

            uint256 currentIdeaId = startId + i;
            vm.expectEmit(true, true, true, false);
            emit IdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IdeaTokenHub.SponsorshipParams(ideaValue, true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);
        }

        IdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(startId);
        assertEq(newInfo.totalFunding, ideaValue);
        assertEq(newInfo.blockCreated, uint32(block.number));
        assertFalse(newInfo.isProposed);
        assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
        assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
        assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
        assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
        assertEq(newInfo.proposal.description, description);
    }

    function test_createIdeaSmartAccount(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, 0.001 ether, type(uint64).max));
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        for (uint256 i; i < numCreators; ++i) {
            uint256 currentIdeaId = startId + i;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);

            address nounder = _createNounderSmartAccount(i);
            vm.deal(nounder, ideaValue);

            vm.expectEmit(true, true, true, false);
            emit IdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IdeaTokenHub.SponsorshipParams(ideaValue, true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);

            IdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, ideaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);
        }
    }

    function test_sponsorIdea(uint8 numCreators, uint8 numSponsors) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        bool eoa;
        for (uint256 i; i < numCreators; ++i) {
            uint256 currentIdeaId = startId + i;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);
            // targets 10e15 order; not truly random but appropriate for testing
            uint256 pseudoRandomIdeaValue = uint256(keccak256(abi.encode(i))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            address nounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            vm.deal(nounder, pseudoRandomIdeaValue);

            vm.expectEmit(true, true, true, false);
            emit IdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        for (uint256 j; j < numSponsors; ++j) {
            assertEq(ideaTokenHub.getNextIdeaId(), uint256(numCreators) + 1);
            // targets 10e16 order; not truly random but appropriate for testing
            uint256 pseudoRandomSponsorValue = uint256(keccak256(abi.encode(j << 2))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            address sponsor = eoa ? _createNounderEOA(numCreators + j) : _createNounderSmartAccount(numCreators + j);
            vm.deal(sponsor, pseudoRandomSponsorValue);

            // reduce an entropic hash to the `[0:nextIdeaId]` range via modulo
            uint256 numIds = ideaTokenHub.getNextIdeaId() - 1;
            // add 1 since modulo produces one less than desired range, incl 0
            uint256 pseudoRandomIdeaId = (uint256(keccak256(abi.encode(j))) % numIds) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IdeaTokenHub.Sponsorship(sponsor, uint96(pseudoRandomIdeaId), IdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false));
            
            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }
    }

    // function test_finalizeAuction() public {}
    // function test_claim()
    // function test_revertTransfer()
    // function test_revertBurn()
    // function test_uri
}