
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public saleActive = false;
    string private _baseTokenURI;

    mapping(address => uint256) public whitelist;
    mapping(uint256 => string) private _tokenURIs;


    event TokenMinted(address to, uint256 tokenId);
    event PriceChanged(uint256 newPrice);
    event SaleStatusChanged(bool status);


    error Error1();
    error Error2();
    error Error3();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) external payable {

        require(saleActive);
        require(msg.value >= mintPrice);
        require(_tokenIdCounter.current() < maxSupply);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);



    }

    function whitelistMint(address to) external {

        require(whitelist[msg.sender] > 0);
        require(_tokenIdCounter.current() < maxSupply);

        whitelist[msg.sender]--;

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);


    }

    function setMintPrice(uint256 newPrice) external onlyOwner {

        if (newPrice == 0) {

            revert Error1();
        }

        mintPrice = newPrice;


        if (newPrice > 1 ether) {

            emit PriceChanged(newPrice);
        }
    }

    function toggleSale() external onlyOwner {
        saleActive = !saleActive;



    }

    function addToWhitelist(address user, uint256 amount) external onlyOwner {

        require(user != address(0));
        require(amount > 0);

        whitelist[user] = amount;


    }

    function removeFromWhitelist(address user) external onlyOwner {

        if (whitelist[user] == 0) {

            revert Error2();
        }

        delete whitelist[user];


    }

    function setBaseURI(string memory baseURI) external onlyOwner {

        require(bytes(baseURI).length > 0);

        _baseTokenURI = baseURI;


    }

    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {

        if (!_exists(tokenId)) {

            revert Error3();
        }

        _tokenURIs[tokenId] = uri;


    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);

        payable(owner()).transfer(balance);


    }

    function emergencyWithdraw(address payable to) external onlyOwner {

        require(to != address(0));

        uint256 balance = address(this).balance;
        to.transfer(balance);


    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {

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

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
