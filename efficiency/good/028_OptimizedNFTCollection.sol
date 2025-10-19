
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OptimizedNFTCollection is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;


    struct TokenInfo {
        address creator;
        uint96 royaltyFee;
    }


    Counters.Counter private _tokenIdCounter;


    mapping(uint256 => TokenInfo) private _tokenInfo;
    mapping(address => bool) public authorizedMinters;


    uint256 public maxSupply;
    uint256 public mintPrice;
    uint96 public defaultRoyaltyFee;
    bool public publicMintEnabled;


    event TokenMinted(uint256 indexed tokenId, address indexed to, address indexed creator);
    event MinterAuthorized(address indexed minter, bool authorized);
    event RoyaltyUpdated(uint256 indexed tokenId, uint96 royaltyFee);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint96 _defaultRoyaltyFee
    ) ERC721(name, symbol) {
        require(_maxSupply > 0, "Invalid max supply");
        require(_defaultRoyaltyFee <= 1000, "Royalty fee too high");

        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        defaultRoyaltyFee = _defaultRoyaltyFee;


        _tokenIdCounter.increment();
    }


    function mint(address to, string memory uri)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");


        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply <= maxSupply, "Max supply reached");


        if (!authorizedMinters[msg.sender]) {
            require(publicMintEnabled, "Public mint disabled");
            require(msg.value >= mintPrice, "Insufficient payment");
        }

        uint256 tokenId = currentSupply;
        _tokenIdCounter.increment();


        _tokenInfo[tokenId] = TokenInfo({
            creator: msg.sender,
            royaltyFee: defaultRoyaltyFee
        });

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(tokenId, to, msg.sender);


        if (msg.value > mintPrice && !authorizedMinters[msg.sender]) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }


    function batchMint(
        address[] calldata recipients,
        string[] calldata uris
    ) external onlyOwner {
        require(recipients.length == uris.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays");


        uint256 currentSupply = _tokenIdCounter.current();
        uint256 batchSize = recipients.length;

        require(currentSupply + batchSize <= maxSupply, "Exceeds max supply");


        uint256 tokenId = currentSupply;
        TokenInfo memory tokenInfo = TokenInfo({
            creator: msg.sender,
            royaltyFee: defaultRoyaltyFee
        });

        for (uint256 i = 0; i < batchSize;) {
            address recipient = recipients[i];
            require(recipient != address(0), "Invalid recipient");

            _tokenInfo[tokenId] = tokenInfo;
            _safeMint(recipient, tokenId);
            _setTokenURI(tokenId, uris[i]);

            emit TokenMinted(tokenId, recipient, msg.sender);

            unchecked {
                ++i;
                ++tokenId;
            }
        }


        for (uint256 i = 0; i < batchSize;) {
            _tokenIdCounter.increment();
            unchecked { ++i; }
        }
    }


    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Token does not exist");


        TokenInfo storage info = _tokenInfo[tokenId];
        receiver = info.creator;
        royaltyAmount = (salePrice * info.royaltyFee) / 10000;
    }


    function setMinterAuthorization(address minter, bool authorized)
        external
        onlyOwner
    {
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }

    function setPublicMintEnabled(bool enabled) external onlyOwner {
        publicMintEnabled = enabled;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function updateTokenRoyalty(uint256 tokenId, uint96 royaltyFee)
        external
    {
        require(_exists(tokenId), "Token does not exist");
        require(royaltyFee <= 1000, "Royalty fee too high");

        TokenInfo storage info = _tokenInfo[tokenId];
        require(msg.sender == info.creator || msg.sender == owner(), "Not authorized");

        info.royaltyFee = royaltyFee;
        emit RoyaltyUpdated(tokenId, royaltyFee);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }


    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (address creator, uint96 royaltyFee)
    {
        require(_exists(tokenId), "Token does not exist");
        TokenInfo memory info = _tokenInfo[tokenId];
        return (info.creator, info.royaltyFee);
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
        delete _tokenInfo[tokenId];
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
