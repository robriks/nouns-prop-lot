// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// import '@openzeppelin/contracts/utils/Strings.sol';
// import '@uniswap/v3-core/contracts/libraries/BitMath.sol';
// import 'base64-sol/base64.sol';

import { IIdeaTokenHub } from "../interfaces/IIdeaTokenHub.sol";

/// @title NFTSVG
/// @notice Provides a function for generating an SVG associated with a PropLot idea
/// inspired by UNI: https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/NFTSVG.sol
contract NFTSVG {
    // using Strings for uint256;

    struct SVGParams {
        uint256 tokenId;
        string color;
    }

    // don't actually need this here, just need it for spiking out the leaderboard
    // I imagine the IdeaTokenHub would implement this...
     struct Sponsor {
        address sponsor;
        uint216 contributedBalance;
    }

    address public tokenAddress;

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory svg) {
        return
            string(
                abi.encodePacked(
                    generateSVGDefs(params),
                    generateSVGBody(params),
                    '</svg>'
                )
            );
    }

    function generateSVGDefs(SVGParams memory params) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<svg width="290" height="500" viewBox="0 0 290 500" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges"',
                " xmlns:xlink='http://www.w3.org/1999/xlink'>",
                '<defs>',
                '<style>',
                '@import url("https://fonts.googleapis.com/css?family=IBM+Plex+Mono:400,400i,700,700i")',
                '.left { fill: #ffffff70; }',
                '.right { fill: #fff; text-anchor: end; }',
                '</style>',
                '</defs>',
                '<rect width="100%" height="100%" rx="15" fill='"#",
                 params.color,
                '"/>'
            )
        );
    }

    function generateSVGBody(SVGParams memory params) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<g transform="translate(10, 10)">',
                // generateNounsGlasses(),
                generateHeader(params.tokenId),
                generateTitle(params.tokenId),
                generateLeaderboard(params.tokenId),
                '</g>'
            )
        );
    }

    function generateHeader(uint256 tokenId) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<g transform="translate(0, 0)">',
                '<text x="20" y="35" font-family="IBM Plex Mono" font-size="16" fill="white">NOUNS DAO LOT</text>',
                '<text x="20" y="50" font-family="IBM Plex Mono" font-size="10" fill="white" opacity=".7">NOUNS.DAO.LOT/IDEA-',
                tokenId, // to string?
                '</text>'
                '</g>'
            )
        );
    }

    function generateTitle(uint256 tokenId) private pure returns (string memory svg) {
        IdeaInfo details = IIdeaTokenHub(tokenAddress).getIdeaInfo(tokenId);
        string memory description = details.proposal.description;

        svg = string(
            abi.encodePacked(
                '<g transform="translate(0, 80)">',
                '<text x="20" y="35" font-family="IBM Plex Mono" font-size="16" fill="white" opacity=".7">IDEA</text>',
                '<text x="20" y="65" font-family="IBM Plex Mono" font-size="20" fill="white">HERE IS THE GREAT</text>',
                '<text x="20" y="90" font-family="IBM Plex Mono" font-size="20" fill="white">IDEA</text>',
                '</g>'
            )
        );
    }

    function generateLeaderboard(uint256 tokenId) private pure returns (string memory svg) {

        // mock data -- replace with some function call like
        // Sponsor[] memory leaders = IIdeaTokenHub(tokenAddress).getLeaderboard(tokenId);
        // this should return max 5 for layout reasons
        Sponsor[] memory leaders = [
            Sponsor({sponsor: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, contributedBalance: 500}),
            Sponsor({sponsor: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, contributedBalance: 400}),
            Sponsor({sponsor: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, contributedBalance: 300}),
            Sponsor({sponsor: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, contributedBalance: 200}),
            Sponsor({sponsor: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, contributedBalance: 100})
        ];


        // each leader requires 2 lines of svg
        string[] memory parts = new string[](leaders.length * 2);

        for (uint256 index = 0; index < leaders.length; index++) {
            Sponsor memory leader = leaders[index];
            uint256 y = 20 + index*20;
            uint256 offset = index*2;
            parts[offset] = string(abi.encodePacked('<text x="20" y="',y.toString(),'" font-family="IBM Plex Mono" font-size="16" fill="white" opacity=".7" class="left">',leader.sponsor,'</text>'));
            parts[offset + 1] = string(abi.encodePacked('<text x="250" y="',y.toString(),'" font-family="IBM Plex Mono" font-size="16" fill="white" class="right">',leader.contributedBalance,'</text>'));
        }

        bytes memory innerContent;
        for (uint256 i = 0; i < parts.length; i++) {
            innerContent = abi.encodePacked(innerContent, parts[i]);
        }

        svg = string(
            abi.encodePacked(
                '<g transform="translate(0, 310)">',
                innerContent,
                '</g>'
            )
        );
    }
}
