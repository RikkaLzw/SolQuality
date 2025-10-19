
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OptimizedNFTCollection is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIdCounter;


    struct TokenInfo {
        uint128 mintPrice;
        uint64 mintTimestamp;
        uint32 royaltyBps;
        uint32 reserved;
    }


    mapping(uint256 => TokenInfo) private _tokenInfo;
    mapping(address => uint256) private _mintCount;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_ADDRESS = 10;
    uint256 public constant DEFAULT_ROYALTY_BPS = 500;


    uint256 public mintPrice = 0.05 ether;
    bool public mintingActive = false;
    string private _baseTokenURI;


    event MintPriceUpdated(uint256 newPrice);
    event MintingToggled(bool active);
    event BaseURIUpdated(string newBaseURI);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
    }


    function mint(address to, string memory uri) external payable nonReentrant {
        require(mintingActive, "Minting not active");


        uint256 currentSupply = totalSupply();
        uint256 currentMintCount = _mintCount[to];

        require(currentSupply < MAX_SUPPLY, "Max supply reached");
        require(currentMintCount < MAX_MINT_PER_ADDRESS, "Max mint per address exceeded");
        require(msg.value >= mintPrice, "Insufficient payment");


        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();


        unchecked {
            _mintCount[to] = currentMintCount + 1;
        }


        _tokenInfo[tokenId] = TokenInfo({
            mintPrice: uint128(msg.value),
            mintTimestamp: uint64(block.timestamp),
            royaltyBps: uint32(DEFAULT_ROYALTY_BPS),
            reserved: 0
        });

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }


    function batchMint(address[] calldata recipients, string[] calldata uris)
        external
        onlyOwner
        nonReentrant
    {
        require(recipients.length == uris.length, "Arrays length mismatch");

        uint256 length = recipients.length;
        uint256 currentSupply = totalSupply();

        require(currentSupply + length <= MAX_SUPPLY, "Exceeds max supply");


        uint256 currentTokenId = _tokenIdCounter.current();

        for (uint256 i = 0; i < length;) {
            address recipient = recipients[i];
            require(recipient != address(0), "Invalid recipient");

            _tokenInfo[currentTokenId] = TokenInfo({
                mintPrice: 0,
                mintTimestamp: uint64(block.timestamp),
                royaltyBps: uint32(DEFAULT_ROYALTY_BPS),
                reserved: 0
            });

            _safeMint(recipient, currentTokenId);
            _setTokenURI(currentTokenId, uris[i]);

            unchecked {
                ++currentTokenId;
                ++i;
            }
        }


        for (uint256 i = 0; i < length;) {
            _tokenIdCounter.increment();
            unchecked { ++i; }
        }
    }


    function tokenInfo(uint256 tokenId) external view returns (TokenInfo memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenInfo[tokenId];
    }

    function getMintCount(address account) external view returns (uint256) {
        return _mintCount[account];
    }

    function getRemainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }


    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;
        emit MintingToggled(mintingActive);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function updateTokenRoyalty(uint256 tokenId, uint32 royaltyBps) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(royaltyBps <= 1000, "Royalty too high");

        _tokenInfo[tokenId].royaltyBps = royaltyBps;
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
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


    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Token does not exist");

        uint256 royalty = (salePrice * _tokenInfo[tokenId].royaltyBps) / 10000;
        return (owner(), royalty);
    }
}
