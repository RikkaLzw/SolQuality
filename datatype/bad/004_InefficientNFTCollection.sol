
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxMintPerTx = 10;
    uint256 public saleStatus = 0;


    mapping(uint256 => string) public tokenCategories;
    mapping(address => string) public userRoles;


    mapping(uint256 => bytes) public tokenMetadata;
    mapping(address => bytes) public userPreferences;


    mapping(address => uint256) public whitelistStatus;
    mapping(uint256 => uint256) public tokenLockStatus;

    constructor() ERC721("Inefficient NFT Collection", "INFT") {}

    function mint(uint256 quantity) public payable {

        require(uint256(saleStatus) == uint256(1), "Sale is not active");
        require(quantity > 0 && quantity <= uint256(maxMintPerTx), "Invalid quantity");
        require(_tokenIdCounter.current() + quantity <= uint256(maxSupply), "Exceeds max supply");
        require(msg.value >= uint256(mintPrice) * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);


            tokenCategories[tokenId] = "standard";


            tokenMetadata[tokenId] = abi.encodePacked("metadata_", tokenId);


            tokenLockStatus[tokenId] = uint256(0);
        }
    }

    function whitelistMint(uint256 quantity) public payable {

        require(uint256(whitelistStatus[msg.sender]) == uint256(1), "Not whitelisted");
        require(uint256(saleStatus) == uint256(1), "Sale is not active");
        require(quantity > 0 && quantity <= uint256(maxMintPerTx), "Invalid quantity");
        require(_tokenIdCounter.current() + quantity <= uint256(maxSupply), "Exceeds max supply");


        uint256 discountedPrice = (uint256(mintPrice) * uint256(80)) / uint256(100);
        require(msg.value >= discountedPrice * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);

            tokenCategories[tokenId] = "whitelist";
            tokenMetadata[tokenId] = abi.encodePacked("wl_metadata_", tokenId);
            tokenLockStatus[tokenId] = uint256(0);
        }
    }

    function setSaleStatus(uint256 _status) public onlyOwner {

        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        saleStatus = _status;
    }

    function addToWhitelist(address user) public onlyOwner {

        whitelistStatus[user] = uint256(1);


        userRoles[user] = "whitelisted";


        userPreferences[user] = abi.encodePacked("premium_user");
    }

    function removeFromWhitelist(address user) public onlyOwner {
        whitelistStatus[user] = uint256(0);
        userRoles[user] = "regular";
        userPreferences[user] = abi.encodePacked("standard_user");
    }

    function lockToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        tokenLockStatus[tokenId] = uint256(1);
    }

    function unlockToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        tokenLockStatus[tokenId] = uint256(0);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {

        require(uint256(tokenLockStatus[tokenId]) == uint256(0), "Token is locked");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        require(uint256(tokenLockStatus[tokenId]) == uint256(0), "Token is locked");
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(uint256(tokenLockStatus[tokenId]) == uint256(0), "Token is locked");
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function setTokenCategory(uint256 tokenId, string memory category) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");

        tokenCategories[tokenId] = category;
    }

    function updateTokenMetadata(uint256 tokenId, bytes memory metadata) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");

        tokenMetadata[tokenId] = metadata;
    }

    function setMintPrice(uint256 _price) public onlyOwner {

        mintPrice = uint256(_price);
    }

    function setMaxMintPerTx(uint256 _max) public onlyOwner {

        require(_max > 0 && _max <= uint256(50), "Invalid max mint per tx");
        maxMintPerTx = uint256(_max);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function isWhitelisted(address user) public view returns (uint256) {

        return whitelistStatus[user];
    }

    function isTokenLocked(uint256 tokenId) public view returns (uint256) {

        return tokenLockStatus[tokenId];
    }

    function isSaleActive() public view returns (uint256) {

        return saleStatus;
    }
}
