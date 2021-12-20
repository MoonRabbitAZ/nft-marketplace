// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IMarketplace {
    enum ListingType {
        FixedPrice,
        Auction
    }

    enum ListingStatus {
        Pending,
        Active,
        Successful,
        Rejected
    }

    struct ListingInfo {
        uint256 blockOfCreation;
        uint256 timeStart;
        uint256 duration;
        uint256 minimalBid;
        uint256 lastBid;
        address lastBidder;
        address creator;
        ListingType listingType;
    }

    event AuctionStepChanged(uint256 newAuctionStep);

    event GracePeriodChanged(uint256 newGracePeriod);

    event CollectionCreated(address indexed collection, address indexed creator, string indexed name, string symbol);

    event CollectionImported(address indexed collection);

    event ListingStarted(address indexed collection, uint256 indexed tokenId, ListingType indexed listingType, uint256 minimalBid, uint256 blockNum);

    event AuctionBid(address indexed collection, uint256 indexed tokenId, address indexed bidder, uint256 amount, uint256 blockTimestamp);

    event NFTPurchased(address indexed collection, uint256 indexed tokenId, address indexed newOwner, uint256 payed);

    event NFTClaimed(address indexed collection, uint256 indexed tokenId, address indexed newOwner, uint256 payed);

    event NFTReturnedFromSale(address indexed collection, uint256 indexed tokenId, address indexed recipient);

    event UnreturnedBidsClaimed(address recipient, uint256 amount);

    function auctionStep() external view returns (uint256);

    function gracePeriod() external view returns (uint256);

    function allCollectionsLength() external view returns (uint256);

    function allExternalCollectionsLength() external view returns (uint256);

    function getCollection(uint256 index) external view returns (address);

    function getExternalCollection(uint256 index) external view returns (address);

    function getListingInfo(address collection, uint256 tokenId) external view returns (ListingInfo memory);

    function getListingStatus(address collection, uint256 tokenId) external view returns (ListingStatus);

    function getListingType(address collection, uint256 tokenId) external view returns (ListingType);

    function setAuctionStep(uint256 newAuctionStep) external;

    function setGracePeriod(uint256 newGracePeriod) external;

    function createNFTWithAuction(
        address collection,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        uint256 royalty
    ) external;

    function createNFTWithFixedPrice(
        address collection,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 value,
        uint256 royalty
    ) external;

    function startAuction(
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid
    ) external;

    function startFixedPrice(
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 duration,
        uint256 value
    ) external;

    function createCollection(
        string calldata collectionURI,
        string calldata name,
        string calldata symbol
    ) external returns (address);

    function importCollection(
        address collection
    ) external;

    function bid(address collection, uint256 tokenId) external payable;

    function purchase(address collection, uint256 tokenId) external payable;

    function claimNFT(address collection, uint256 tokenId) external;

    function claimUnreturnedBids() external;

    function returnFromSale(address collection, uint256 tokenId) external;

    function stopListing(address collection, uint256 tokenId) external;
}
