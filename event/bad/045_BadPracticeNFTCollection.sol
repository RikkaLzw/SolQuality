
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingEnabled = false;
    string private _baseTokenURI;

    mapping(address => uint256) public mintedCount;
    mapping(uint256 => string) private _tokenURIs;


    event MintingToggled(bool enabled);
    event PriceChanged(uint256 newPrice);
    event BaseURIChanged(string newURI);
    event TokenMinted(address to, uint256 tokenId);


    error Failed();
    error NotAllowed();
    error Invalid();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) public payable {

        require(mintingEnabled);
        require(msg.value >= mintPrice);
        require(_tokenIdCounter.current() < maxSupply);
        require(mintedCount[to] < 5);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);
        mintedCount[to]++;

        emit TokenMinted(to, tokenId);
    }

    function batchMint(address[] calldata recipients) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {

            require(_tokenIdCounter.current() < maxSupply);

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(recipients[i], tokenId);
            mintedCount[recipients[i]]++;
        }

    }

    function setMintingEnabled(bool enabled) external onlyOwner {
        if (!enabled && mintingEnabled) {

            if (_tokenIdCounter.current() == 0) {
                mintingEnabled = false;
                return;
            }
        }

        mintingEnabled = enabled;
        emit MintingToggled(enabled);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {

        require(newPrice > 0);

        mintPrice = newPrice;


    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {

        require(newMaxSupply >= _tokenIdCounter.current());
        require(newMaxSupply <= 50000);

        maxSupply = newMaxSupply;

    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {

        require(_exists(tokenId));

        _tokenURIs[tokenId] = uri;

    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);

        (bool success, ) = payable(owner()).call{value: balance}("");

        require(success);

    }

    function emergencyWithdraw(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {

            revert Failed();
        }

        if (recipient == address(0)) {

            revert Invalid();
        }

        (bool success, ) = recipient.call{value: balance}("");
        if (!success) {

            revert Failed();
        }
    }

    function burnToken(uint256 tokenId) external {

        require(_isApprovedOrOwner(_msgSender(), tokenId));

        _burn(tokenId);

    }

    function transferOwnership(address newOwner) public override onlyOwner {

        require(newOwner != address(0));

        super.transferOwnership(newOwner);

    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {

        require(_exists(tokenId));

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }
}
