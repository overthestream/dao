// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FakeNFTMarketplace {
    // token id - owner
    mapping(uint256 => address) public tokens;
    uint256 nftPrice = 0.1 ether;

    // mark owner of token && check price
    function purchase(uint256 _tokenId) external payable {
        require(msg.value == nftPrice, "This NFT costs 0.1 ether");
        tokens[_tokenId] = msg.sender;
    }

    // get price of NFT
    function getPrice() external view returns (uint256) {
        return nftPrice;
    }

    function available(uint256 _tokenId) external view returns (bool) {
        // address(0) == default val, 0x0
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}
