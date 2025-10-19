
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadStyleNFTContract is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private a;
    uint256 public b = 0.01 ether;
    uint256 public c = 10000;
    mapping(uint256 => string) private d;
    bool public e = true;
        string public f = "https://api.example.com/metadata/";

    event temp_event(address indexed user, uint256 tokenId);

    constructor() ERC721("BadStyleNFT", "BSNFT") {}

    function mint_token(address to) public payable {
        require(e, "Minting paused"); require(msg.value >= b, "Insufficient payment");
        uint256 x = a.current();
        require(x < c, "Max supply reached");

        a.increment(); _safeMint(to, x);
        emit temp_event(to, x);
    }

        function batch_mint(address[] memory recipients) public onlyOwner {
    for(uint256 i = 0; i < recipients.length; i++) { uint256 temp1 = a.current(); require(temp1 < c, "Max supply reached"); a.increment(); _safeMint(recipients[i], temp1); }
    }

    function set_base_uri(string memory newBaseURI) public onlyOwner {
        f = newBaseURI;
    }

    function toggle_minting() public onlyOwner { e = !e; }

    function set_price(uint256 newPrice) public onlyOwner {
        b = newPrice;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        string memory baseURI = f;
        return bytes(baseURI).length > 0 ?
            string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json")) : "";
    }

    function withdraw_funds() public onlyOwner {
        uint256 temp2 = address(this).balance;
        require(temp2 > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: temp2}("");
        require(success, "Withdrawal failed");
    }

    function get_total_supply() public view returns (uint256) {
        return a.current();
    }

        function emergency_pause() public onlyOwner {
    e = false;
    }

    function set_token_uri(uint256 tokenId, string memory uri) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        d[tokenId] = uri;
    }
}
