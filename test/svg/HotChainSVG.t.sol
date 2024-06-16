//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { RendererThree } from "../../src/SVG/RendererThree.sol";
import { PolymathDisplayBold } from "../../src/SVG/fonts/PolymathDisplayBold.sol";
import { PolymathTextRegular } from "../../src/SVG/fonts/PolymathTextRegular.sol";


contract HotChainSVG is Test {
    PolymathDisplayBold public displayBold;
    PolymathTextRegular public textRegular;
    RendererThree public r;
    uint256 fork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/gbbxbIHNfMbHaJFe0d5XdfNITz9s7057");

    function setUp() public {
        vm.startPrank(address(123));
        vm.selectFork(fork);

        textRegular = new PolymathTextRegular();
         // replace first arg with proplot contract
        r = new RendererThree(address(this), address(textRegular));

        // string memory polyDisplay = getFileContents("polyDisplay.txt");
        // string memory polyText = getFileContents("polyText.txt");

        string memory polyText = "data:font/otf;charset=utf-8;base64,T1RUTwAKAIAAAwAgQ0ZGIBEKxqAAAAhUAAAXTkdERUYAEgA2AAAfpAAAABZPUy8yaDllaAAAARAAAABgY21hcAF8AmwAAAfQAAAAZGhlYWQnNPxkAAAArAAAADZoaGVhB4gDFQAAAOQAAAAkaG10eJNkDpsAAB+8AAABDG1heHAAQ1AAAAABCAAAAAZuYW1lnKXJXgAAAXAAAAZecG9zdP93ADwAAAg0AAAAIAABAAAAARma7O+Aq18PPPUAAwPoAAAAAOIT4ngAAAAA4kO9hQAC/w8DxALbAAAABgACAAAAAAAAAAEAAAPA/ugAAAPnAAIAAgPEAAEAAAAAAAAAAAAAAAAAAABDAABQAABDAAAABAIzAZAABQAIAooCWAAAAEsCigJYAAABXgA8AUcAAAILBQQDBQIGAwMAAAADAAAAAAAAAAAAAAAAT0hOTwHAACAAoAPA/ugAAAR0Ae0AAAABAAAAAAHSAqkAAAAgAAAAAAARANIAAwABBAkAAAB8AAAAAwABBAkAAQAkAHwAAwABBAkAAgAOAKAAAwABBAkAAwBOAK4AAwABBAkABAA0APwAAwABBAkABQAaATAAAwABBAkABgAwAUoAAwABBAkABwBmAXoAAwABBAkACAAkAeAAAwABBAkACQAkAeAAAwABBAkACwAmAgQAAwABBAkADAAmAgQAAwABBAkADQLuAioAAwABBAkADgBMBRgAAwABBAkAEAAkAHwAAwABBAkAEQAOAKAAAwABBAkAEwAoBWQAQwBvAHAAeQByAGkAZwBoAHQAIACpACAAMgAwADIANAAgAE8ASAAgAG4AbwAgAFQAeQBwAGUAIABDAG8AbQBwAGEAbgB5ACwAIABMAEwAQwAuACAAQQBsAGwAIAByAGkAZwBoAHQAcwAgAHIAZQBzAGUAcgB2AGUAZAAuAFAAbwBsAHkAbQBhAHQAaAAgAFQAZQB4AHQAIABEAGUAbQBvAFIAZQBnAHUAbABhAHIATwBIAE4ATwA6ACAAUABvAGwAeQBtAGEAdABoACAAVABlAHgAdAAgAEQAZQBtAG8AIABSAGUAZwB1AGwAYQByADoAIAAxAC4AMQAwADAAUABvAGwAeQBtAGEAdABoACAAVABlAHgAdAAgAEQAZQBtAG8AIABSAGUAZwB1AGwAYQByAFYAZQByAHMAaQBvAG4AIAAxAC4AMQAwADAAUABvAGwAeQBtAGEAdABoAFQAZQB4AHQARABlAG0AbwAtAFIAZQBnAHUAbABhAHIAUABvAGwAeQBtAGEAdABoACAAaQBzACAAYQAgAHQAcgBhAGQAZQBtAGEAcgBrACAAbwBmACAATwBIACAAbgBvACAAVAB5AHAAZQAgAEMAbwBtAHAAYQBuAHkALAAgAEwATABDAC4ATwBIACAAbgBvACAAVAB5AHAAZQAgAEMAbwBtAHAAYQBuAHkAaAB0AHQAcABzADoALwAvAG8AaABuAG8AdAB5AHAAZQAuAGMAbwBUAGgAaQBzACAAZgBvAG4AdAAgAHMAbwBmAHQAdwBhAHIAZQAgAGkAcwAgAHAAcgBvAHAAZQByAHQAeQAgAG8AZgAgAE8ASAAgAG4AbwAgAFQAeQBwAGUAIABDAG8AbQBwAGEAbgB5ACwAIABMAEwAQwAuACAARABlAG0AbwAgAGYAbwBuAHQAcwAgAG0AYQB5ACAAYgBlACAAdQBzAGUAZAAgAGYAbwByACAAdABlAHMAdABpAG4AZwAgAGEAbgBkACAAZQB4AHAAZQByAGkAbQBlAG4AdABpAG4AZwAgAHAAdQByAHAAbwBzAGUAcwAgAG8AbgBsAHkALgAgAFUAcwBlACAAaQBuACAAcwB0AHUAZABlAG4AdAAgAHcAbwByAGsAIABpAHMAIABwAGUAcgBtAGkAdAB0AGUAZAAuACAAQgB5ACAAZABvAHcAbgBsAG8AYQBkAGkAbgBnACAAYQBuAGQALwBvAHIAIABpAG4AcwB0AGEAbABsAGkAbgBnACwAIABjAG8AcAB5AGkAbgBnACwAIABvAHIAIAB1AHMAaQBuAGcAIAB0AGgAaQBzACAARgBvAG4AdAAgAFMAbwBmAHQAdwBhAHIAZQAsACAAeQBvAHUAIABhAGcAcgBlAGUAIAB0AGgAZQAgAHQAZQByAG0AcwAgAG8AZgAgAG8AdQByACAARQBuAGQALQBVAHMAZQByACAATABpAGMAZQBuAHMAZQAgAEEAZwByAGUAZQBtAGUAbgB0AC4AIABZAG8AdQAgAGMAYQBuACAAZgBpAG4AZAAgAGEAIABjAG8AcAB5ACAAbwBmACAAdABoAGUAIABBAGcAcgBlAGUAbQBlAG4AdAAgAG8AbgBsAGkAbgBlACAAYQB0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BXSlfLKyGrOUp6ysHq6uBaamtJu1G7KsfnOkHxMAIBAArq73CYYFEwIABACJawUTACgAAKqq8YcFykcur/sCG/t6+zX7Nvt4HxPoKZQA+wm2J9JGHhMUAkAA9zP3yRXcxMHV3lHCQz9QU0I6w1PSHxNgACEA95r7pxXXwr/d21K9PkNSWjY9xFfWHxMJABQA+wr3tBXih47gx4eIOOGGlvePBRMIQAoANY6HOVCNBRMCAAgAjt4FEwIBkAA0jwX7m/ytFeGQhun3KC+NjH33kzWGkDP7KeSJigUTFAJAAPcW7hVzeKSqpZqdpKiZanJxeXt1HxNgACEA95L7pxVyfJ6oqZugo6Wad29ygHFtHw74JnkV91/3Gfcs92L3YvsZ9y37X/tf+xv7Lfti+2L3G/ss918fVx37Mi77DvstHwt61/edyveA1hLO4lPb96XbU+IT8vfOehX3MOfj9wTfTso2pB+RBxPs0qO3wNsa7TXd+xf7FTQ4Kju2VtJzHoUHE/I0c1FMNhr7BOcz9y8e1wQvR8Dd1cfD7+/IU0E5RlYvHxPs99wEP0/AzczBv93ewVdKSU9WPh8OBxM6gNsGE1qAqIuniqkek4wFE5mAR6++bdEbfdMVE5yAWQoTmYApWUMxiR4OAdvd94JrHQugdvhmgx0W3fhmOQYT8DAKDnb4Znf3qncB290Dch0L2gHL4PgZ4AP37HsV90Pz9zX3WfdYI/cz+0P7RCP7M/tY+1nz+zX3RB8LVQoTmYBzHQvb+3oV3fdZBrWLr3gd9xxD9wD7Ex8L95SFFcAG91L4sfdS/LEFwQYL1PfQ403UgHcL8IMV9MnM9wkf+I82/IkHQ2xlTnt7jI96Hgvbxm47NVJiPB/7TvfFFfd290cHC8J/vHtcGldedFZeYqCvaR5UWAv3fvxhBZgG9374Z5Wfl6aWpRkLBRPo/D4/9zMGtruMjLUf+04L7Bb3swb3D93W9wrqUbdCnR8LXx33tNwLBfcCBuPCUzo4U0UsLVYL92mFFdEG91j4agWNNgcL2ffT1/cp1gH4Xd4D98ALLFLR8O/E0urkvkMpHwvsFt/4oQaXcZdwlXcIC/sUjh8T2PdS95GHC6FranN1a2qjdawfC/tldvdw1Pfp1IB3C2UfiweVz5TQk8wICwG/3vfW3gMLdvgo1PeLdwv7MBXIBvP3uAWNCwAAAAEAAAAMAAAAAAAAAAIAAQACADUAAQAAAzcAFADwAAACrAAdApAAYQLgAEAC0ABhAk0AYQIkAGEDCgBAAuQAYQEWAGEBbQAkApEAYQInAGEDjwBhAvQAYQMiAEACRQBhAyMAQAKQAGECQwA2AiEACwLLAFYCrgAdA+cAIwK/ADMCQwACAngAIgJCAC8CQgBQAfkALwJCAC8CBAAvAWgALAJDAC8CLgBQAPIAQADyAEAB7wBQAPIAUANFAFACLgBQAisALwJCAFACQgAvAV8AUAGfABwBVAAsAicATAHxABMC5wATAf4AIQH4ABMBuAASAq8AQAF7ACwCVAAzAk0AKAJZABkCUAAwAlAANAIVABYCdABDAlAANADpADYA5AAQAPAAAA==";

        textRegular.saveFile(0, polyText);
        textRegular.saveFile(0, polyText);
        vm.stopPrank();
    }

    function test_HotChainSVG() public {
        vm.selectFork(fork);
        string memory webpage = string.concat(
            "<html>",
            "<title>Hot Chain SVG</title>",
            r.generateSVG(442),
            "</html>"
        );

        vm.writeFile("index.html", webpage);
    }
}
