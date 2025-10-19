
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract DigitalArtNFTContract is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIdCounter;


    uint256 public constant MAX_SUPPLY = 10000;


    uint256 public mintPrice = 0.01 ether;


    uint256 public constant MAX_MINT_PER_ADDRESS = 10;


    bool public mintingPaused = false;


    mapping(address => uint256) public addressMintCount;


    address public royaltyReceiver;


    uint256 public royaltyFeeNumerator = 500;


    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyReceiver
    ) ERC721(_name, _symbol) {
        require(_royaltyReceiver != address(0), "Invalid royalty receiver address");
        royaltyReceiver = _royaltyReceiver;


        _tokenIdCounter.increment();
    }


    function mintNFT(string memory _tokenURI) external payable nonReentrant {
        require(!mintingPaused, "Minting is currently paused");
        require(msg.value >= mintPrice, "Insufficient payment amount");
        require(_tokenIdCounter.current() <= MAX_SUPPLY, "Maximum supply reached");
        require(addressMintCount[msg.sender] < MAX_MINT_PER_ADDRESS, "Maximum mint per address exceeded");
        require(bytes(_tokenURI).length > 0, "Token URI cannot be empty");

        uint256 currentTokenId = _tokenIdCounter.current();


        addressMintCount[msg.sender]++;


        _safeMint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, _tokenURI);


        _tokenIdCounter.increment();


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }


    function batchMintNFT(address _to, string[] memory _tokenURIs) external onlyOwner {
        require(_to != address(0), "Cannot mint to zero address");
        require(_tokenURIs.length > 0, "Token URIs array cannot be empty");
        require(_tokenIdCounter.current() + _tokenURIs.length <= MAX_SUPPLY, "Batch mint would exceed max supply");

        for (uint256 i = 0; i < _tokenURIs.length; i++) {
            require(bytes(_tokenURIs[i]).length > 0, "Token URI cannot be empty");

            uint256 currentTokenId = _tokenIdCounter.current();
            _safeMint(_to, currentTokenId);
            _setTokenURI(currentTokenId, _tokenURIs[i]);
            _tokenIdCounter.increment();
        }
    }


    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }


    function setPauseStatus(bool _paused) external onlyOwner {
        mintingPaused = _paused;
    }


    function setRoyaltyInfo(address _receiver, uint256 _feeNumerator) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver address");
        require(_feeNumerator <= 1000, "Royalty fee too high");

        royaltyReceiver = _receiver;
        royaltyFeeNumerator = _feeNumerator;
    }


    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        payable(owner()).transfer(contractBalance);
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }


    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }


    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(_tokenId), "Token does not exist");

        receiver = royaltyReceiver;
        royaltyAmount = (_salePrice * royaltyFeeNumerator) / 10000;
    }


    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }


    function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(_tokenId);
    }


    function emergencyPause() external onlyOwner {
        mintingPaused = true;
    }


    function isContract(address _address) internal view returns (bool) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_address)
        }
        return codeSize > 0;
    }
}
