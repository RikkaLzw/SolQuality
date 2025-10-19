
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTContract is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) private _minters;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public paused = false;


    event TokenMinted(address to, uint256 tokenId);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event MinterAdded(address minter);
    event ContractPaused(bool status);


    error Error1();
    error Error2();
    error Error3();

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}

    function mint(address to) public payable {

        require(!paused);
        require(_tokenIdCounter.current() < maxSupply);
        require(msg.value >= mintPrice);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);




        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }

    function batchMint(address[] memory recipients) public onlyOwner {

        require(!paused);
        require(recipients.length > 0);

        for (uint256 i = 0; i < recipients.length; i++) {

            require(_tokenIdCounter.current() < maxSupply);

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(recipients[i], tokenId);
        }


    }

    function setTokenURI(uint256 tokenId, string memory uri) public {

        require(_exists(tokenId));
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender);

        _tokenURIs[tokenId] = uri;


    }

    function addMinter(address minter) public onlyOwner {

        require(minter != address(0));

        _minters[minter] = true;


        emit MinterAdded(minter);
    }

    function removeMinter(address minter) public onlyOwner {

        require(_minters[minter]);

        _minters[minter] = false;


    }

    function setMintPrice(uint256 newPrice) public onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;


        emit PriceChanged(oldPrice, newPrice);
    }

    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;


        emit ContractPaused(_paused);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);

        payable(owner()).transfer(balance);


    }

    function emergencyWithdraw(address token, uint256 amount) public onlyOwner {

        if (token == address(0)) {
            require(address(this).balance >= amount);
            payable(owner()).transfer(amount);
        }


    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {

        require(_exists(tokenId));

        string memory uri = _tokenURIs[tokenId];
        if (bytes(uri).length > 0) {
            return uri;
        }

        return super.tokenURI(tokenId);
    }

    function isMinter(address account) public view returns (bool) {
        return _minters[account];
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }


    function specialFunction() public {
        if (msg.sender == address(0)) {
            revert Error1();
        }

        if (paused) {
            revert Error2();
        }


    }


    function anotherFunction(uint256 value) public {
        if (value == 0) {
            revert Error3();
        }


    }
}
