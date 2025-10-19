
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxMintPerAddress = 5;
    uint256 public publicSaleStatus = 0;
    uint256 public whitelistSaleStatus = 0;

    Counters.Counter private _tokenIdCounter;


    string public collectionId = "INFT001";
    string public version = "v1.0";


    mapping(uint256 => bytes) public tokenMetadata;
    mapping(address => uint256) public mintedCount;
    mapping(address => uint256) public whitelistStatus;


    bytes public contractMetadata;

    constructor() ERC721("Inefficient NFT Collection", "INFT") {

        maxSupply = uint256(10000);
        mintPrice = uint256(0.01 ether);


        contractMetadata = bytes("QmExampleHashForContractMetadata123456789");
    }

    modifier onlyDuringPublicSale() {

        require(publicSaleStatus == 1, "Public sale not active");
        _;
    }

    modifier onlyDuringWhitelistSale() {

        require(whitelistSaleStatus == 1, "Whitelist sale not active");
        _;
    }

    function setPublicSaleStatus(uint256 _status) external onlyOwner {

        publicSaleStatus = _status;
    }

    function setWhitelistSaleStatus(uint256 _status) external onlyOwner {

        whitelistSaleStatus = _status;
    }

    function addToWhitelist(address _user) external onlyOwner {

        whitelistStatus[_user] = 1;
    }

    function removeFromWhitelist(address _user) external onlyOwner {

        whitelistStatus[_user] = 0;
    }

    function whitelistMint(uint256 _quantity) external payable onlyDuringWhitelistSale {

        require(whitelistStatus[msg.sender] == 1, "Not whitelisted");
        require(_quantity > 0, "Quantity must be positive");


        require(uint256(_tokenIdCounter.current()) + _quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + _quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * _quantity, "Insufficient payment");


        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);


            tokenMetadata[tokenId] = bytes(string(abi.encodePacked("QmExampleHash", toString(tokenId))));
        }

        mintedCount[msg.sender] += _quantity;
    }

    function publicMint(uint256 _quantity) external payable onlyDuringPublicSale {
        require(_quantity > 0, "Quantity must be positive");


        require(uint256(_tokenIdCounter.current()) + _quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + _quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * _quantity, "Insufficient payment");


        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);


            tokenMetadata[tokenId] = bytes(string(abi.encodePacked("QmExampleHash", toString(tokenId))));
        }

        mintedCount[msg.sender] += _quantity;
    }

    function ownerMint(address _to, uint256 _quantity) external onlyOwner {
        require(_to != address(0), "Invalid address");
        require(_quantity > 0, "Quantity must be positive");


        require(uint256(_tokenIdCounter.current()) + _quantity <= maxSupply, "Exceeds max supply");


        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(_to, tokenId);


            tokenMetadata[tokenId] = bytes(string(abi.encodePacked("QmExampleHash", toString(tokenId))));
        }
    }

    function setMintPrice(uint256 _newPrice) external onlyOwner {

        mintPrice = uint256(_newPrice);
    }

    function setMaxMintPerAddress(uint256 _newMax) external onlyOwner {

        maxMintPerAddress = uint256(_newMax);
    }

    function setTokenMetadata(uint256 _tokenId, bytes memory _metadata) external onlyOwner {
        require(_exists(_tokenId), "Token does not exist");

        tokenMetadata[_tokenId] = _metadata;
    }

    function setContractMetadata(bytes memory _metadata) external onlyOwner {

        contractMetadata = _metadata;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist");


        return string(tokenMetadata[_tokenId]);
    }

    function totalSupply() public view returns (uint256) {

        return uint256(_tokenIdCounter.current());
    }

    function isWhitelisted(address _user) public view returns (uint256) {

        return whitelistStatus[_user];
    }

    function isPublicSaleActive() public view returns (uint256) {

        return publicSaleStatus;
    }

    function isWhitelistSaleActive() public view returns (uint256) {

        return whitelistSaleStatus;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
