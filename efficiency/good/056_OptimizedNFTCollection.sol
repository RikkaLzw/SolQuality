
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedNFTCollection is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIdCounter;


    struct CollectionConfig {
        uint256 maxSupply;
        uint256 mintPrice;
        uint256 maxPerWallet;
        bool publicMintActive;
    }

    CollectionConfig public config;


    mapping(address => uint256) private _walletMintCount;
    mapping(uint256 => address) private _tokenCreators;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event ConfigUpdated(uint256 maxSupply, uint256 mintPrice, uint256 maxPerWallet);
    event PublicMintToggled(bool active);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet
    ) ERC721(name, symbol) {
        config = CollectionConfig({
            maxSupply: _maxSupply,
            mintPrice: _mintPrice,
            maxPerWallet: _maxPerWallet,
            publicMintActive: false
        });


        _tokenIdCounter.increment();
    }


    function mint(address to, string memory uri)
        external
        payable
        nonReentrant
        whenNotPaused
    {

        CollectionConfig memory _config = config;

        require(_config.publicMintActive, "Public mint not active");
        require(msg.value >= _config.mintPrice, "Insufficient payment");

        uint256 currentTokenId = _tokenIdCounter.current();
        require(currentTokenId <= _config.maxSupply, "Max supply reached");


        uint256 walletMintCount = _walletMintCount[to];
        require(walletMintCount < _config.maxPerWallet, "Max per wallet exceeded");


        _walletMintCount[to] = walletMintCount + 1;
        _tokenCreators[currentTokenId] = to;


        _safeMint(to, currentTokenId);
        _setTokenURI(currentTokenId, uri);

        _tokenIdCounter.increment();

        emit TokenMinted(to, currentTokenId, uri);


        uint256 excess = msg.value - _config.mintPrice;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }


    function ownerMint(address to, string memory uri)
        external
        onlyOwner
        whenNotPaused
    {
        uint256 currentTokenId = _tokenIdCounter.current();
        require(currentTokenId <= config.maxSupply, "Max supply reached");

        _tokenCreators[currentTokenId] = to;

        _safeMint(to, currentTokenId);
        _setTokenURI(currentTokenId, uri);

        _tokenIdCounter.increment();

        emit TokenMinted(to, currentTokenId, uri);
    }


    function batchMint(address[] memory recipients, string[] memory uris)
        external
        onlyOwner
        whenNotPaused
    {
        require(recipients.length == uris.length, "Arrays length mismatch");
        require(recipients.length <= 20, "Batch size too large");

        uint256 currentTokenId = _tokenIdCounter.current();
        uint256 maxSupply = config.maxSupply;

        require(currentTokenId + recipients.length <= maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < recipients.length;) {
            address recipient = recipients[i];
            _tokenCreators[currentTokenId] = recipient;

            _safeMint(recipient, currentTokenId);
            _setTokenURI(currentTokenId, uris[i]);

            emit TokenMinted(recipient, currentTokenId, uris[i]);

            unchecked {
                ++currentTokenId;
                ++i;
            }
        }


        for (uint256 j = 0; j < recipients.length;) {
            _tokenIdCounter.increment();
            unchecked { ++j; }
        }
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }

    function getWalletMintCount(address wallet) external view returns (uint256) {
        return _walletMintCount[wallet];
    }

    function getTokenCreator(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenCreators[tokenId];
    }

    function getRemainingSupply() external view returns (uint256) {
        uint256 current = _tokenIdCounter.current() - 1;
        return config.maxSupply > current ? config.maxSupply - current : 0;
    }


    function updateConfig(
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet
    ) external onlyOwner {
        require(_maxSupply >= _tokenIdCounter.current() - 1, "Max supply too low");

        config.maxSupply = _maxSupply;
        config.mintPrice = _mintPrice;
        config.maxPerWallet = _maxPerWallet;

        emit ConfigUpdated(_maxSupply, _mintPrice, _maxPerWallet);
    }

    function togglePublicMint() external onlyOwner {
        config.publicMintActive = !config.publicMintActive;
        emit PublicMintToggled(config.publicMintActive);
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

        payable(owner()).transfer(balance);
    }


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _tokenCreators[tokenId];
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


    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }
}
