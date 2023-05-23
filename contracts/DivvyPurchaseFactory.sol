// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DivvyPurchaseController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DivvyPurchaseFactory is AccessControl {
    mapping(address => uint256[]) public tokenIds; // collectionAddress => tokenId[]

    nft[] public nfts;
    address[] public paymentTokens;

    address controllersAdmin;

    event ListItem(address collection, uint256 tokenId);

    struct nft {
        address collection;
        uint256 tokenId;
        address controller;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        controllersAdmin = msg.sender;
    }

    function listItem(
        address collection,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    ) public {
        require(
            paymentTokenExists(paymentToken) || paymentToken == address(0),
            "Invalid payment token!"
        );
        require(price > 0, "price <= 0");
        require(!isTokenListed(collection, tokenId), "Already listed!");

        DivvyPurchaseController controller = new DivvyPurchaseController(
            controllersAdmin,
            collection,
            tokenId,
            price,
            paymentToken
        );

        tokenIds[collection].push(tokenId);
        nfts.push(
            nft({
                collection: collection,
                tokenId: tokenId,
                controller: address(controller)
            })
        );

        emit ListItem(collection, tokenId);
    }

    function addPaymentToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!paymentTokenExists(token), "Already exists");
        paymentTokens.push(token);
    }

    function removePaymentToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                delete paymentTokens[i];
            }
        }
    }

    function setControllersAdmin(
        address admin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(admin != address(0), "!admin");
        controllersAdmin = admin;
    }

    function paymentTokenExists(address token) public view returns (bool) {
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function isTokenListed(
        address collection,
        uint256 tokenId
    ) public view returns (bool) {
        for (uint256 i = 0; i < tokenIds[collection].length; i++) {
            if (tokenIds[collection][i] == tokenId) {
                return true;
            }
        }
        return false;
    }
}
