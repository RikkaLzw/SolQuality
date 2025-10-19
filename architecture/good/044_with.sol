
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract PremiumNFTCollection is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TRANSACTION = 5;
    uint256 public constant MINT_PRICE = 0.05 ether;


    Counters.Counter private _tokenIdCounter;
    string private _baseTokenURI;
    bool public publicMintEnabled;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;


    event MintPriceUpdated(uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);
    event WhitelistUpdated(address indexed user, bool status);
    event PublicMintToggled(bool enabled);


    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] || publicMintEnabled, "Not whitelisted");
        _;
    }

    modifier validMintAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TRANSACTION, "Invalid mint amount");
        _;
    }

    modifier supplyAvailable(uint256 amount) {
        require(_tokenIdCounter.current() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _;
    }

    modifier correctPayment(uint256 amount) {
        require(msg.value >= MINT_PRICE * amount, "Insufficient payment");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        publicMintEnabled = false;
    }


    function mint(address to, uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
        onlyWhitelisted
        validMintAmount(amount)
        supplyAvailable(amount)
        correctPayment(amount)
    {
        _mintTokens(to, amount);
    }


    function ownerMint(address to, uint256 amount)
        external
        onlyOwner
        validMintAmount(amount)
        supplyAvailable(amount)
    {
        _mintTokens(to, amount);
    }


    function batchMintWithURI(
        address to,
        string[] calldata tokenURIs
    ) external onlyOwner supplyAvailable(tokenURIs.length) {
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = _getNextTokenId();
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);
        }
    }


    function setTokenURI(uint256 tokenId, string calldata tokenURI)
        external
        onlyOwner
    {
        require(_exists(tokenId), "Token does not exist");
        _setTokenURI(tokenId, tokenURI);
    }


    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }


    function updateWhitelist(address[] calldata addresses, bool status)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = status;
            emit WhitelistUpdated(addresses[i], status);
        }
    }


    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
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


    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }


    function _mintTokens(address to, uint256 amount) private {
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _getNextTokenId();
            _safeMint(to, tokenId);
        }
        mintedCount[to] += amount;
    }


    function _getNextTokenId() private returns (uint256) {
        _tokenIdCounter.increment();
        return _tokenIdCounter.current();
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }


    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }


    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
