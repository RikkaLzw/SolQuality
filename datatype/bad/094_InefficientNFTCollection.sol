
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxMintPerAddress = 5;


    string public collectionId = "INFT001";
    string public version = "1.0";


    uint256 public mintingActive = 1;
    uint256 public revealed = 0;

    Counters.Counter private _tokenIdCounter;


    mapping(uint256 => bytes) public tokenMetadata;
    mapping(address => uint256) public mintedCount;


    string public baseTokenURI = "https://api.example.com/metadata/";
    string public hiddenMetadataUri = "https://api.example.com/hidden.json";

    constructor() ERC721("Inefficient NFT Collection", "INFT") {}

    function mint(uint256 quantity) external payable {

        require(uint256(mintingActive) == 1, "Minting is not active");
        require(quantity > 0, "Quantity must be greater than 0");
        require(quantity <= uint256(10), "Cannot mint more than 10 at once");

        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply + quantity <= maxSupply, "Exceeds maximum supply");

        uint256 userMinted = mintedCount[msg.sender];
        require(userMinted + quantity <= maxMintPerAddress, "Exceeds maximum mint per address");


        require(msg.value >= mintPrice * uint256(quantity), "Insufficient payment");

        mintedCount[msg.sender] += quantity;


        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);


            tokenMetadata[tokenId] = abi.encodePacked("metadata_", tokenId);
        }
    }

    function setMintingActive(uint256 _active) external onlyOwner {

        mintingActive = _active;
    }

    function setRevealed(uint256 _revealed) external onlyOwner {

        revealed = _revealed;
    }

    function setBaseURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) external onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {

        require(uint256(_maxSupply) >= _tokenIdCounter.current(), "Cannot set max supply below current supply");
        maxSupply = _maxSupply;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");


        if (revealed == 0) {
            return hiddenMetadataUri;
        }


        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
    }

    function getTokenMetadata(uint256 tokenId) external view returns (bytes memory) {

        require(_exists(tokenId), "Token does not exist");
        return tokenMetadata[tokenId];
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function batchMint(address[] memory recipients, uint256[] memory quantities) external onlyOwner {
        require(recipients.length == quantities.length, "Arrays length mismatch");


        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 quantity = quantities[i];


            for (uint256 j = 0; j < quantity; j++) {
                uint256 tokenId = _tokenIdCounter.current();
                _tokenIdCounter.increment();
                _safeMint(recipient, tokenId);


                tokenMetadata[tokenId] = abi.encodePacked("batch_metadata_", tokenId);
            }
        }
    }


    function setCollectionId(string memory _collectionId) external onlyOwner {
        collectionId = _collectionId;
    }


    function getMintingStatus() external view returns (uint256, uint256, uint256) {
        return (
            uint256(mintingActive),
            uint256(revealed),
            uint256(_tokenIdCounter.current())
        );
    }
}
