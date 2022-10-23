// SPDX-License-Identifier:MIT  SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
error NFTMarketplace__PriceMustBeAboveSero();
error NFTMarketplace__NotApprovedForMarketplace();
error NFTMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__NotOwner();
error NFTMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NFTMarketplace__NoProceeds();
error NFTMarketplace__transerFailed();
contract NFTMarketplace is ReentrancyGuard{
    constructor() {}

    struct Listing {
        uint256 price;
        address seller;
    }
    //evnts
    event ItemListed(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemBought(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCancelled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    //seller to amount earned
    mapping(address => uint256) private s_proceeds;
    modifier notListed(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Listing memory listing = s_listings[_nftAddress][_tokenId];
        if (listing.price > 0) {
            revert NFTMarketplace__AlreadyListed(_nftAddress, _tokenId);
        }
        _;
    }
    modifier isListed(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Listing memory listing = s_listings[_nftAddress][_tokenId];
        if (listing.price <= 0) {
            revert NFTMarketplace__NotListed(_nftAddress, _tokenId);
        }
        _;
    }
    modifier isOwner(
        address _nftAddress,
        uint256 _tokenId,
        address _spender
    ) {
        IERC721 nft = IERC721(_nftAddress);
        address owner = nft.ownerOf(_tokenId);
        if (_spender != owner) {
            revert NFTMarketplace__NotOwner();
        }
        _;
    }

    //////////////////
    /// Main Functions //abi//===
    //////////////////abi
    function listItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        notListed(_nftAddress, _tokenId)
        isOwner(_nftAddress, _tokenId, msg.sender)
    {
        if (_price <= 0) {
            revert NFTMarketplace__PriceMustBeAboveSero();
        }
        IERC721 nft = IERC721(_nftAddress);
        if (nft.getApproved(_tokenId) != address(this)) {
            revert NFTMarketplace__NotApprovedForMarketplace();
        }

        s_listings[_nftAddress][_tokenId] = Listing(_price, msg.sender);

        emit ItemListed(msg.sender, _nftAddress, _tokenId, _price);
    }

    function buyItem(address _nftAddress, uint256 _tokenId) 
    external payable nonReentrant isListed(_nftAddress, _tokenId) {
        Listing memory listedItem = s_listings[_nftAddress][_tokenId];
        if(msg.value < listedItem.price) {
            revert NFTMarketplace__PriceNotMet(_nftAddress, _tokenId, listedItem.price);
        }
        s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
        delete (s_listings[_nftAddress][_tokenId]);
        IERC721(_nftAddress).safeTransferFrom(listedItem.seller, msg.sender, _tokenId);

        emit ItemBought(msg.sender, _nftAddress, _tokenId, listedItem.price);
    }

    function cancelListing(address _nftAddress, uint256 _tokenId) external 
    isOwner(_nftAddress, _tokenId, msg.sender) isListed(_nftAddress, _tokenId) {
        delete (s_listings[_nftAddress][_tokenId]);
        emit ItemCancelled(msg.sender, _nftAddress, _tokenId);
    }

    function updateListing(address _nftAddress, uint256 _tokenId, uint256 _newPrice) external 
    isOwner(_nftAddress, _tokenId, msg.sender) isListed(_nftAddress, _tokenId) {
        s_listings[_nftAddress][_tokenId].price = _newPrice;
        emit ItemListed(msg.sender, _nftAddress, _tokenId, _newPrice);
    }

    function withdrawProceeds() external payable {
        uint256 proceeds = s_proceeds[msg.sender];
        if(proceeds <= 0){
            revert NFTMarketplace__NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: proceeds}("");
        if(!sent){
            revert NFTMarketplace__transerFailed();
        }
    }

   //getters
   function getListing(address _nftAddress, uint256 _tokenId) external view returns(Listing memory){
       return s_listings[_nftAddress][_tokenId];
   }
   function getProceeds(address seller) external view returns(uint256){
      return s_proceeds[seller];
   }

}
