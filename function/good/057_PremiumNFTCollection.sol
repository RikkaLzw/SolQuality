
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.08 ether;
    uint256 public maxMintPerAddress = 5;
    bool public mintingActive = false;

    mapping(address => uint256) private _mintedCount;

    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event MintPriceUpdated(uint256 newPrice);
    event MintingStatusChanged(bool status);

    constructor() ERC721("Premium NFT Collection", "PNC") {}

    function mint(address to, string memory uri) external payable nonReentrant {
        require(mintingActive, "Minting is not active");
        require(to != address(0), "Invalid recipient address");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_canMint(to), "Minting limit exceeded");
        require(_hasSupplyRemaining(), "Max supply reached");

        uint256 tokenId = _getNextTokenId();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _incrementMintCount(to);

        emit TokenMinted(to, tokenId);
    }

    function batchMint(address to, string[] memory uris) external payable nonReentrant {
        require(mintingActive, "Minting is not active");
        require(to != address(0), "Invalid recipient address");
        require(uris.length > 0 && uris.length <= 3, "Invalid batch size");
        require(msg.value >= mintPrice * uris.length, "Insufficient payment");
        require(_canBatchMint(to, uris.length), "Batch minting limit exceeded");

        for (uint256 i = 0; i < uris.length; i++) {
            require(_hasSupplyRemaining(), "Max supply reached");
            uint256 tokenId = _getNextTokenId();
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
            _incrementMintCount(to);
            emit TokenMinted(to, tokenId);
        }
    }

    function ownerMint(address to, string memory uri) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        require(_hasSupplyRemaining(), "Max supply reached");

        uint256 tokenId = _getNextTokenId();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized to burn");
        _burn(tokenId);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setMaxMintPerAddress(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Limit must be positive");
        maxMintPerAddress = newLimit;
    }

    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;
        emit MintingStatusChanged(mintingActive);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getMintedCount(address account) external view returns (uint256) {
        return _mintedCount[account];
    }

    function getRemainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter.current();
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _canMint(address account) internal view returns (bool) {
        return _mintedCount[account] < maxMintPerAddress;
    }

    function _canBatchMint(address account, uint256 amount) internal view returns (bool) {
        return _mintedCount[account] + amount <= maxMintPerAddress;
    }

    function _hasSupplyRemaining() internal view returns (bool) {
        return _tokenIdCounter.current() < MAX_SUPPLY;
    }

    function _getNextTokenId() internal returns (uint256) {
        _tokenIdCounter.increment();
        return _tokenIdCounter.current();
    }

    function _incrementMintCount(address account) internal {
        _mintedCount[account]++;
    }
}
