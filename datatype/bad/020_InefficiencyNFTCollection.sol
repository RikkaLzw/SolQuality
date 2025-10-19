
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficiencyNFTCollection is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxPerWallet = 5;
    uint256 public isPublicSaleActive = 0;
    uint256 public isWhitelistSaleActive = 0;


    string public collectionType = "PREMIUM";
    string public rarityLevel = "LEGENDARY";


    bytes public contractSignature;
    bytes public metadataHash;

    mapping(address => uint256) public walletMintCount;
    mapping(address => uint256) public isWhitelisted;
    mapping(uint256 => bytes) public tokenMetadata;
    mapping(uint256 => string) public tokenCategory;

    event TokenMinted(address indexed to, uint256 indexed tokenId, string category);
    event WhitelistStatusChanged(address indexed user, uint256 status);

    constructor() ERC721("InefficiencyNFTCollection", "INFT") {
        contractSignature = abi.encodePacked("INFT_CONTRACT_V1");
        metadataHash = abi.encodePacked(keccak256("METADATA_HASH"));
    }

    function setPublicSaleActive(uint256 _active) external onlyOwner {

        isPublicSaleActive = _active;
    }

    function setWhitelistSaleActive(uint256 _active) external onlyOwner {

        isWhitelistSaleActive = _active;
    }

    function addToWhitelist(address _user) external onlyOwner {

        isWhitelisted[_user] = 1;
        emit WhitelistStatusChanged(_user, 1);
    }

    function removeFromWhitelist(address _user) external onlyOwner {

        isWhitelisted[_user] = 0;
        emit WhitelistStatusChanged(_user, 0);
    }

    function whitelistMint(string memory _tokenURI, string memory _category) external payable {
        require(isWhitelistSaleActive == 1, "Whitelist sale not active");
        require(isWhitelisted[msg.sender] == 1, "Not whitelisted");
        require(msg.value >= mintPrice, "Insufficient payment");


        uint256 currentSupply = uint256(_tokenIdCounter.current());
        require(currentSupply < maxSupply, "Max supply reached");
        require(walletMintCount[msg.sender] < maxPerWallet, "Max per wallet reached");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);


        tokenCategory[tokenId] = _category;
        tokenMetadata[tokenId] = abi.encodePacked(_tokenURI, _category);


        walletMintCount[msg.sender] = uint256(walletMintCount[msg.sender] + 1);

        emit TokenMinted(msg.sender, tokenId, _category);
    }

    function publicMint(string memory _tokenURI, string memory _category) external payable {
        require(isPublicSaleActive == 1, "Public sale not active");
        require(msg.value >= mintPrice, "Insufficient payment");


        uint256 currentSupply = uint256(_tokenIdCounter.current());
        require(currentSupply < maxSupply, "Max supply reached");
        require(walletMintCount[msg.sender] < maxPerWallet, "Max per wallet reached");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);


        tokenCategory[tokenId] = _category;
        tokenMetadata[tokenId] = abi.encodePacked(_tokenURI, _category);


        walletMintCount[msg.sender] = uint256(walletMintCount[msg.sender] + 1);

        emit TokenMinted(msg.sender, tokenId, _category);
    }

    function ownerMint(address _to, string memory _tokenURI, string memory _category) external onlyOwner {

        uint256 currentSupply = uint256(_tokenIdCounter.current());
        require(currentSupply < maxSupply, "Max supply reached");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);


        tokenCategory[tokenId] = _category;
        tokenMetadata[tokenId] = abi.encodePacked(_tokenURI, _category);

        emit TokenMinted(_to, tokenId, _category);
    }

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }

    function setMaxSupply(uint256 _newMaxSupply) external onlyOwner {

        require(_newMaxSupply >= _tokenIdCounter.current(), "Cannot reduce below current supply");
        maxSupply = _newMaxSupply;
    }

    function setMaxPerWallet(uint256 _newMax) external onlyOwner {

        maxPerWallet = _newMax;
    }

    function updateContractSignature(bytes memory _newSignature) external onlyOwner {

        contractSignature = _newSignature;
    }

    function updateMetadataHash(bytes memory _newHash) external onlyOwner {

        metadataHash = _newHash;
    }

    function setCollectionType(string memory _newType) external onlyOwner {

        collectionType = _newType;
    }

    function setRarityLevel(string memory _newLevel) external onlyOwner {

        rarityLevel = _newLevel;
    }

    function getTotalSupply() external view returns (uint256) {

        return uint256(_tokenIdCounter.current());
    }

    function getTokenMetadata(uint256 _tokenId) external view returns (bytes memory) {

        require(_exists(_tokenId), "Token does not exist");
        return tokenMetadata[_tokenId];
    }

    function isTokenOwner(address _user, uint256 _tokenId) external view returns (uint256) {

        if (ownerOf(_tokenId) == _user) {
            return 1;
        }
        return 0;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
