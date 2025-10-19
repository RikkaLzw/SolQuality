
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PremiumArtNFT is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TX = 20;
    uint256 public constant MAX_MINT_PER_ADDRESS = 100;


    Counters.Counter private _tokenIdCounter;
    uint256 public mintPrice = 0.08 ether;
    uint256 public maxSupply = MAX_SUPPLY;
    bool public publicMintEnabled = false;


    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;
    mapping(uint256 => bool) private _exists;


    event MintPriceUpdated(uint256 newPrice);
    event PublicMintToggled(bool enabled);
    event WhitelistUpdated(address indexed account, bool whitelisted);
    event BaseURIUpdated(string newBaseURI);


    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] || publicMintEnabled, "Not whitelisted or public mint disabled");
        _;
    }

    modifier validMintAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid mint amount");
        require(mintedCount[msg.sender] + amount <= MAX_MINT_PER_ADDRESS, "Exceeds max mint per address");
        _;
    }

    modifier supplyAvailable(uint256 amount) {
        require(_tokenIdCounter.current() + amount <= maxSupply, "Exceeds max supply");
        _;
    }

    modifier correctPayment(uint256 amount) {
        require(msg.value >= mintPrice * amount, "Insufficient payment");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
    }


    string private _baseTokenURI;

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
        emit BaseURIUpdated(baseTokenURI);
    }


    function mint(uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
        onlyWhitelisted
        validMintAmount(amount)
        supplyAvailable(amount)
        correctPayment(amount)
    {
        _mintTokens(msg.sender, amount);
    }

    function ownerMint(address to, uint256 amount)
        external
        onlyOwner
        supplyAvailable(amount)
    {
        _mintTokens(to, amount);
    }

    function _mintTokens(address to, uint256 amount) private {
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
            _exists[tokenId] = true;
        }
        mintedCount[to] += amount;
    }


    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply >= _tokenIdCounter.current(), "Cannot set below current supply");
        require(newMaxSupply <= MAX_SUPPLY, "Cannot exceed absolute max supply");
        maxSupply = newMaxSupply;
    }

    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
    }

    function updateWhitelist(address[] calldata addresses, bool whitelisted) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = whitelisted;
            emit WhitelistUpdated(addresses[i], whitelisted);
        }
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

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists[tokenId];
    }

    function getMintedCount(address account) external view returns (uint256) {
        return mintedCount[account];
    }

    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }


    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
        _exists[tokenId] = false;
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
