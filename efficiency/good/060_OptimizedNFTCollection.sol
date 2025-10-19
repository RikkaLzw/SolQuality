
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OptimizedNFTCollection is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    struct ContractConfig {
        uint128 maxSupply;
        uint128 mintPrice;
        bool mintingActive;
        bool revealed;
        uint32 maxMintPerTx;
        uint32 maxMintPerWallet;
    }

    ContractConfig public config;
    Counters.Counter private _tokenIdCounter;


    mapping(address => uint256) private _mintedCount;
    mapping(uint256 => bool) private _exists;


    event MintingStatusChanged(bool active);
    event RevealStatusChanged(bool revealed);
    event ConfigUpdated(uint128 maxSupply, uint128 mintPrice, uint32 maxMintPerTx, uint32 maxMintPerWallet);

    constructor(
        string memory name,
        string memory symbol,
        uint128 _maxSupply,
        uint128 _mintPrice,
        uint32 _maxMintPerTx,
        uint32 _maxMintPerWallet
    ) ERC721(name, symbol) {
        config = ContractConfig({
            maxSupply: _maxSupply,
            mintPrice: _mintPrice,
            mintingActive: false,
            revealed: false,
            maxMintPerTx: _maxMintPerTx,
            maxMintPerWallet: _maxMintPerWallet
        });
    }


    function mint(uint256 quantity) external payable nonReentrant {
        ContractConfig memory _config = config;
        require(_config.mintingActive, "Minting not active");
        require(quantity > 0 && quantity <= _config.maxMintPerTx, "Invalid quantity");

        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply + quantity <= _config.maxSupply, "Exceeds max supply");

        uint256 userMinted = _mintedCount[msg.sender];
        require(userMinted + quantity <= _config.maxMintPerWallet, "Exceeds wallet limit");
        require(msg.value >= _config.mintPrice * quantity, "Insufficient payment");


        _mintedCount[msg.sender] = userMinted + quantity;


        for (uint256 i = 0; i < quantity; ) {
            uint256 tokenId = currentSupply + i;
            _tokenIdCounter.increment();
            _exists[tokenId] = true;
            _safeMint(msg.sender, tokenId);

            unchecked {
                ++i;
            }
        }
    }


    function ownerMint(address to, uint256 quantity) external onlyOwner {
        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply + quantity <= config.maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < quantity; ) {
            uint256 tokenId = currentSupply + i;
            _tokenIdCounter.increment();
            _exists[tokenId] = true;
            _safeMint(to, tokenId);

            unchecked {
                ++i;
            }
        }
    }


    function setTokenURIs(uint256[] calldata tokenIds, string[] calldata uris) external onlyOwner {
        require(tokenIds.length == uris.length, "Arrays length mismatch");

        for (uint256 i = 0; i < tokenIds.length; ) {
            require(_exists[tokenIds[i]], "Token does not exist");
            _setTokenURI(tokenIds[i], uris[i]);

            unchecked {
                ++i;
            }
        }
    }


    function updateConfig(
        uint128 _maxSupply,
        uint128 _mintPrice,
        uint32 _maxMintPerTx,
        uint32 _maxMintPerWallet
    ) external onlyOwner {
        require(_maxSupply >= _tokenIdCounter.current(), "Max supply too low");

        config.maxSupply = _maxSupply;
        config.mintPrice = _mintPrice;
        config.maxMintPerTx = _maxMintPerTx;
        config.maxMintPerWallet = _maxMintPerWallet;

        emit ConfigUpdated(_maxSupply, _mintPrice, _maxMintPerTx, _maxMintPerWallet);
    }

    function setMintingActive(bool active) external onlyOwner {
        config.mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setRevealed(bool revealed) external onlyOwner {
        config.revealed = revealed;
        emit RevealStatusChanged(revealed);
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function totalSupply() public view override returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getMintedCount(address user) external view returns (uint256) {
        return _mintedCount[user];
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists[tokenId], "Token does not exist");
        return super.tokenURI(tokenId);
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists[tokenId];
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
        _exists[tokenId] = false;
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
