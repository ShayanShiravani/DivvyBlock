// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDivvyERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DivvyPurchaseController is AccessControl, IERC721Receiver, Pausable {
    bytes4 public constant _ERC721_RECEIVED = 0x150b7a02;

    mapping(uint256 => offer) public offers; // offerId => offer
    uint256 public lastOfferId = 0;

    address public collection;
    uint256 public tokenId;
    uint256 public price;
    address public paymentToken; // TODO: Support multiple payment tokens
    bool public isListed = true;

    event AddOffer(uint256 offerId, address initiator, uint256 initialAmount);
    event Purchase(uint256 offerId);

    struct offer {
        address initiator;
        uint256 currentAmount;
        uint256 minShareAmount;
        PurchaseShare[] shares;
        bool isDone;
    }

    struct PurchaseShare {
        address stakeholder;
        uint256 amount;
    }

    constructor(
        address _admin,
        address _collection,
        uint256 _tokenId,
        uint256 _price,
        address _paymentToken
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        collection = _collection;
        tokenId = _tokenId;
        price = _price;
        paymentToken = _paymentToken;
    }

    function changePrice(uint256 _price) public {
        require(_price > 0, "price <= 0");
        price = _price;
    }

    function makeOffer(
        uint256 minShareAmount,
        uint256 shareAmount
    ) public payable whenNotPaused returns (uint256 offerId) {
        require(isListed, "!isListed");
        require(minShareAmount > 0, "minShareAmount <= 0");
        require(
            shareAmount > 0 &&
                shareAmount <= price &&
                shareAmount >= minShareAmount,
            "Invalid share amount!"
        );

        // It can be modified to support multiple payment tokens
        if (paymentToken == address(0)) {
            require(msg.value == shareAmount, "!Share amount");
        } else {
            IERC20 token = IERC20(paymentToken);
            token.transferFrom(msg.sender, address(this), shareAmount);
        }

        offerId = ++lastOfferId;

        offer storage newOffer = offers[offerId];

        newOffer.initiator = msg.sender;
        newOffer.currentAmount = shareAmount;
        newOffer.minShareAmount = minShareAmount;
        newOffer.isDone = false;

        require(
            price - shareAmount >= minShareAmount || price == shareAmount,
            "Remained amount < minShareAmount"
        );

        newOffer.shares.push(
            PurchaseShare({stakeholder: msg.sender, amount: shareAmount})
        );

        if (shareAmount == price) {
            purchaseNFT(offerId);
        }

        emit AddOffer(offerId, msg.sender, shareAmount);
    }

    function addShare(
        uint256 offerId,
        uint256 amount
    ) public payable whenNotPaused {
        require(isListed, "!isListed");
        require(offers[offerId].initiator != address(0), "!offer");

        offer storage _offer = offers[offerId];

        require(!_offer.isDone, "It's already done!");
        require(
            amount >= _offer.minShareAmount &&
                (amount + _offer.currentAmount) <= price,
            "Invalid share amount!"
        );

        if (paymentToken == address(0)) {
            require(msg.value == amount, "!Share amount");
        } else {
            IERC20 token = IERC20(paymentToken);
            token.transferFrom(msg.sender, address(this), amount);
        }

        _offer.shares.push(
            PurchaseShare({stakeholder: msg.sender, amount: amount})
        );
        _offer.currentAmount += amount;

        require(
            price - _offer.currentAmount >= _offer.minShareAmount ||
                price == _offer.currentAmount,
            "Remained amount < minShareAmount"
        );

        if (_offer.currentAmount == price) {
            purchaseNFT(offerId);
        }
    }

    function deleteShare(uint256 offerId, uint256 index) public whenNotPaused {
        require(offers[offerId].initiator != address(0), "!offer");

        offer storage _offer = offers[offerId];

        require(index < _offer.shares.length, "Invalid index!");

        PurchaseShare memory share = _offer.shares[index];
        require(
            !_offer.isDone && (msg.sender == share.stakeholder),
            "Permission denied!"
        );

        _offer.currentAmount -= share.amount;

        for (uint256 i = index; i < _offer.shares.length - 1; i++) {
            _offer.shares[i] = _offer.shares[i + 1];
        }

        _offer.shares.pop();

        if (paymentToken == address(0)) {
            payable(msg.sender).transfer(share.amount);
        } else {
            IERC20(paymentToken).transfer(msg.sender, share.amount);
        }
    }

    function purchaseNFT(uint256 offerId) private {
        offer storage _offer = offers[offerId];

        IDivvyERC721 nft = IDivvyERC721(collection);

        address owner = nft.ownerOf(tokenId);
        nft.safeTransferFrom(owner, address(this), tokenId);

        _offer.isDone = true;
        isListed = false;

        if (paymentToken == address(0)) {
            payable(owner).transfer(price);
        } else {
            IERC20(paymentToken).transfer(owner, price);
        }

        emit Purchase(offerId);
    }

    function relist() public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        isListed = true;
    }

    function unlist() public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        isListed = false;
    }

    function getStakeholders(
        uint256 offerId
    ) public view returns (address[] memory stakeholders) {
        offer memory _offer = offers[offerId];

        stakeholders = new address[](_offer.shares.length);
        for (uint256 i = 0; i < _offer.shares.length; i++) {
            stakeholders[i] = _offer.shares[i].stakeholder;
        }
    }

    function getShare(
        uint256 offerId,
        uint256 index
    ) public view returns (address stakeholder, uint256 amount) {
        offer memory _offer = offers[offerId];

        stakeholder = _offer.shares[index].stakeholder;
        amount = _offer.shares[index].amount;
    }

    function transferToken(
        address to
    ) public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        IDivvyERC721 nft = IDivvyERC721(collection);
        nft.safeTransferFrom(address(this), to, tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return _ERC721_RECEIVED;
    }
}
