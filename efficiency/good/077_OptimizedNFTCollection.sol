
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OptimizedNFTCollection is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    struct MintConfig {
        uint128 maxSupply;
        uint128 mintPrice;
    }

    MintConfig public mintConfig;
    Counters.Counter private _tokenIdCounter;


    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;


    event WhitelistUpdated(address indexed account, bool status);
    event MintConfigUpdated(uint128 maxSupply, uint128 mintPrice);
    event BatchMinted(address indexed to, uint256 startTokenId, uint256 quantity);


    error ExceedsMaxSupply();
    error InsufficientPayment();
    error NotWhitelisted();
    error ExceedsMaxPerWallet();
    error InvalidQuantity();
    error WithdrawFailed();

    constructor(
        string memory name,
        string memory symbol,
        uint128 _maxSupply,
        uint128 _mintPrice
    ) ERC721(name, symbol) {
        mintConfig = MintConfig({
            maxSupply: _maxSupply,
            mintPrice: _mintPrice
        });
    }


    function mint(address to, string memory uri) external payable nonReentrant {
        MintConfig memory config = mintConfig;
        uint256 currentTokenId = _tokenIdCounter.current();

        if (currentTokenId >= config.maxSupply) revert ExceedsMaxSupply();
        if (msg.value < config.mintPrice) revert InsufficientPayment();

        _tokenIdCounter.increment();
        _safeMint(to, currentTokenId);
        _setTokenURI(currentTokenId, uri);
    }


    function batchMint(
        address to,
        string[] calldata uris
    ) external payable nonReentrant {
        uint256 quantity = uris.length;
        if (quantity == 0) revert InvalidQuantity();

        MintConfig memory config = mintConfig;
        uint256 currentTokenId = _tokenIdCounter.current();

        if (currentTokenId + quantity > config.maxSupply) revert ExceedsMaxSupply();
        if (msg.value < config.mintPrice * quantity) revert InsufficientPayment();

        uint256 startTokenId = currentTokenId;


        for (uint256 i = 0; i < quantity;) {
            _safeMint(to, currentTokenId);
            _setTokenURI(currentTokenId, uris[i]);

            unchecked {
                ++currentTokenId;
                ++i;
            }
        }


        for (uint256 i = 0; i < quantity;) {
            _tokenIdCounter.increment();
            unchecked { ++i; }
        }

        emit BatchMinted(to, startTokenId, quantity);
    }


    function whitelistMint(
        address to,
        string memory uri,
        uint256 maxPerWallet
    ) external payable nonReentrant {
        if (!whitelist[msg.sender]) revert NotWhitelisted();

        uint256 currentMinted = mintedCount[msg.sender];
        if (currentMinted >= maxPerWallet) revert ExceedsMaxPerWallet();

        MintConfig memory config = mintConfig;
        uint256 currentTokenId = _tokenIdCounter.current();

        if (currentTokenId >= config.maxSupply) revert ExceedsMaxSupply();
        if (msg.value < config.mintPrice) revert InsufficientPayment();


        mintedCount[msg.sender] = currentMinted + 1;
        _tokenIdCounter.increment();

        _safeMint(to, currentTokenId);
        _setTokenURI(currentTokenId, uri);
    }


    function updateWhitelist(
        address[] calldata addresses,
        bool status
    ) external onlyOwner {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length;) {
            whitelist[addresses[i]] = status;
            emit WhitelistUpdated(addresses[i], status);
            unchecked { ++i; }
        }
    }


    function updateMintConfig(
        uint128 _maxSupply,
        uint128 _mintPrice
    ) external onlyOwner {
        mintConfig = MintConfig({
            maxSupply: _maxSupply,
            mintPrice: _mintPrice
        });
        emit MintConfigUpdated(_maxSupply, _mintPrice);
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert WithdrawFailed();
    }


    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getRemainingSupply() external view returns (uint256) {
        return mintConfig.maxSupply - _tokenIdCounter.current();
    }

    function getMintPrice() external view returns (uint256) {
        return mintConfig.mintPrice;
    }

    function getMaxSupply() external view returns (uint256) {
        return mintConfig.maxSupply;
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
