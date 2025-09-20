// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract ConfidentialAuctionFHE is SepoliaConfig {

    struct Auction {
        uint256 id;
        string title;
        string description;
        string category;
        uint256 minimumBid;
        address creator;
        uint256 timestamp;
        bool isActive;
        uint256 endTime;
        euint64 highestBidAmount; // Encrypted highest bid amount
        address highestBidder;
        uint256 bidCount;
        ebool hasHighBid; // Encrypted boolean for bid status
    }

    struct Bid {
        address bidder;
        euint64 amount; // Encrypted bid amount
        ebool isHighBid; // Encrypted bid status
        string comments;
        uint256 timestamp;
        bool isRevealed;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => mapping(uint256 => bool)) public hasUserBid;

    uint256 public nextAuctionId = 1;
    uint256 public totalAuctions = 0;

    event AuctionCreated(
        uint256 indexed auctionId,
        string title,
        string category,
        uint256 minimumBid,
        address indexed creator,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        string comments,
        uint256 timestamp
    );

    constructor() {}

    function createAuction(
        string memory _title,
        string memory _description,
        string memory _category,
        uint256 _minimumBid
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_minimumBid > 0, "Minimum bid must be greater than 0");

        uint256 auctionId = nextAuctionId;

        // Create auction with encrypted zero values
        _createAuctionInternal(auctionId, _title, _description, _category, _minimumBid);

        userAuctions[msg.sender].push(auctionId);
        totalAuctions++;
        nextAuctionId++;

        emit AuctionCreated(auctionId, _title, _category, _minimumBid, msg.sender, block.timestamp + 7 days);
    }

    function _createAuctionInternal(
        uint256 _auctionId,
        string memory _title,
        string memory _description,
        string memory _category,
        uint256 _minimumBid
    ) internal {
        uint256 endTime = block.timestamp + 7 days;
        euint64 encryptedZero = FHE.asEuint64(0);
        ebool encryptedFalse = FHE.asEbool(false);

        FHE.allowThis(encryptedZero);
        FHE.allowThis(encryptedFalse);

        auctions[_auctionId] = Auction({
            id: _auctionId,
            title: _title,
            description: _description,
            category: _category,
            minimumBid: _minimumBid,
            creator: msg.sender,
            timestamp: block.timestamp,
            isActive: true,
            endTime: endTime,
            highestBidAmount: encryptedZero,
            highestBidder: address(0),
            bidCount: 0,
            hasHighBid: encryptedFalse
        });
    }

    function placeBid(
        uint256 _auctionId,
        bool _isHighBid,
        uint256 _bidAmount,
        string memory _comments
    ) external payable {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(_bidAmount >= auctions[_auctionId].minimumBid, "Bid too low");
        require(msg.value >= _bidAmount, "Insufficient payment");

        _placeBidInternal(_auctionId, _isHighBid, _bidAmount, _comments);
        emit BidPlaced(_auctionId, msg.sender, _comments, block.timestamp);
    }

    function _placeBidInternal(
        uint256 _auctionId,
        bool _isHighBid,
        uint256 _bidAmount,
        string memory _comments
    ) internal {
        // Encrypt the bid amount and status using FHE
        euint64 encryptedAmount = FHE.asEuint64(uint64(_bidAmount));
        ebool encryptedIsHigh = FHE.asEbool(_isHighBid);

        // Grant access permissions for encrypted data
        FHE.allowThis(encryptedAmount);
        FHE.allowThis(encryptedIsHigh);
        FHE.allow(encryptedAmount, msg.sender);
        FHE.allow(encryptedIsHigh, msg.sender);

        // Store the encrypted bid
        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: encryptedAmount,
            isHighBid: encryptedIsHigh,
            comments: _comments,
            timestamp: block.timestamp,
            isRevealed: false
        }));

        // Update auction data
        _updateAuctionBid(_auctionId, _isHighBid, encryptedAmount, encryptedIsHigh);
    }

    function _updateAuctionBid(
        uint256 _auctionId,
        bool _isHighBid,
        euint64 _encryptedAmount,
        ebool _encryptedIsHigh
    ) internal {
        Auction storage auction = auctions[_auctionId];
        auction.bidCount++;
        hasUserBid[msg.sender][_auctionId] = true;

        if (_isHighBid) {
            auction.highestBidAmount = _encryptedAmount;
            auction.highestBidder = msg.sender;
            auction.hasHighBid = _encryptedIsHigh;
        }
    }

    // View functions that return non-encrypted data for frontend compatibility
    function getTotalCounts() external view returns (uint256 totalAuctionCount, uint256 activeAuctionCount) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }
        return (totalAuctions, activeCount);
    }

    function getAuctionBasicInfo(uint256 _auctionId) external view returns (
        string memory title,
        string memory description,
        string memory category,
        uint256 minimumBid,
        address creator
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.title, auction.description, auction.category, auction.minimumBid, auction.creator);
    }

    function getAuctionStatus(uint256 _auctionId) external view returns (
        uint256 timestamp,
        bool isActive,
        uint256 endTime,
        uint256 bidCount
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.timestamp, auction.isActive && block.timestamp < auction.endTime, auction.endTime, auction.bidCount);
    }

    function getBidCount(uint256 _auctionId) external view returns (uint256) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].bidCount;
    }

    function getUserAuctions(address _user) external view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function hasUserBidOnAuction(address _user, uint256 _auctionId) external view returns (bool) {
        return hasUserBid[_user][_auctionId];
    }

    function getHighestBidder(uint256 _auctionId) external view returns (address) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].highestBidder;
    }

    // Admin functions
    function endAuction(uint256 _auctionId) external {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].creator == msg.sender, "Only creator can end auction");
        auctions[_auctionId].isActive = false;
    }

    function withdrawFunds() external {
        require(msg.sender == address(this), "Only contract owner");
        payable(msg.sender).transfer(address(this).balance);
    }
}