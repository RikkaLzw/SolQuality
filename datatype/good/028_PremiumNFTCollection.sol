
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TX = 10;
    uint256 public mintPrice = 0.05 ether;

    bool public publicMintEnabled = false;
    bool public whitelistMintEnabled = false;

    bytes32 public merkleRoot;

    mapping(address => bool) public hasMinted;
    mapping(address => uint8) public mintCount;

    event MintPriceUpdated(uint256 newPrice);
    event PublicMintToggled(bool enabled);
    event WhitelistMintToggled(bool enabled);
    event MerkleRootUpdated(bytes32 newRoot);

    constructor(
        string memory name,
        string memory symbol,
        bytes32 _merkleRoot
    ) ERC721(name, symbol) {
        merkleRoot = _merkleRoot;
    }

    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }

    modifier withinSupplyLimit(uint8 quantity) {
        require(_tokenIdCounter.current() + quantity <= MAX_SUPPLY, "Exceeds maximum supply");
        _;
    }

    modifier validMintQuantity(uint8 quantity) {
        require(quantity > 0 && quantity <= MAX_MINT_PER_TX, "Invalid mint quantity");
        _;
    }

    modifier correctPayment(uint8 quantity) {
        require(msg.value >= mintPrice * quantity, "Insufficient payment");
        _;
    }

    function publicMint(uint8 quantity)
        external
        payable
        whenNotPaused
        nonReentrant
        validMintQuantity(quantity)
        withinSupplyLimit(quantity)
        correctPayment(quantity)
    {
        require(publicMintEnabled, "Public mint not enabled");
        require(mintCount[msg.sender] + quantity <= MAX_MINT_PER_TX, "Exceeds per-address limit");

        mintCount[msg.sender] += quantity;

        for (uint8 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
        }
    }

    function whitelistMint(uint8 quantity, bytes32[] calldata merkleProof)
        external
        payable
        whenNotPaused
        nonReentrant
        validMintQuantity(quantity)
        withinSupplyLimit(quantity)
        correctPayment(quantity)
    {
        require(whitelistMintEnabled, "Whitelist mint not enabled");
        require(!hasMinted[msg.sender], "Already minted");
        require(_verifyMerkleProof(merkleProof, msg.sender), "Invalid merkle proof");

        hasMinted[msg.sender] = true;

        for (uint8 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
        }
    }

    function ownerMint(address to, uint8 quantity)
        external
        onlyOwner
        validMintQuantity(quantity)
        withinSupplyLimit(quantity)
    {
        for (uint8 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri)
        external
        onlyOwner
        validTokenId(tokenId)
    {
        _setTokenURI(tokenId, uri);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
    }

    function toggleWhitelistMint() external onlyOwner {
        whitelistMintEnabled = !whitelistMintEnabled;
        emit WhitelistMintToggled(whitelistMintEnabled);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
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

    function _verifyMerkleProof(bytes32[] calldata proof, address addr)
        private
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == merkleRoot;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        validTokenId(tokenId)
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
}
