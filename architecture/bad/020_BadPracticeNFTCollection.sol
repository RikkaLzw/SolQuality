
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract BadPracticeNFTCollection {
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    mapping(uint256 => string) internal _tokenURIs;

    string internal _name;
    string internal _symbol;
    uint256 internal _currentIndex;
    address public owner;
    bool public mintingEnabled;
    uint256 public mintPrice;
    uint256 public maxSupply;
    uint256 public maxPerWallet;
    mapping(address => uint256) public mintedPerWallet;
    mapping(uint256 => bool) public tokenExists;
    string public baseTokenURI;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event MintingToggled(bool enabled);
    event PriceUpdated(uint256 newPrice);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        owner = msg.sender;
        _currentIndex = 1;
        mintingEnabled = true;
        mintPrice = 0.01 ether;
        maxSupply = 10000;
        maxPerWallet = 5;
        baseTokenURI = "https://api.example.com/metadata/";
    }

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address owner_) public view returns (uint256) {

        if (owner_ == address(0)) {
            revert("ERC721: address zero is not a valid owner");
        }
        return _balances[owner_];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {

        if (!tokenExists[tokenId]) {
            revert("ERC721: invalid token ID");
        }
        address owner_ = _owners[tokenId];
        if (owner_ == address(0)) {
            revert("ERC721: invalid token ID");
        }
        return owner_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {

        if (!tokenExists[tokenId]) {
            revert("ERC721: invalid token ID");
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseTokenURI;

        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return string(abi.encodePacked(base, toString(tokenId)));
    }

    function approve(address to, uint256 tokenId) public {
        address owner_ = ownerOf(tokenId);

        if (to == owner_) {
            revert("ERC721: approval to current owner");
        }
        if (msg.sender != owner_ && !isApprovedForAll(owner_, msg.sender)) {
            revert("ERC721: approve caller is not token owner or approved for all");
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {

        if (!tokenExists[tokenId]) {
            revert("ERC721: invalid token ID");
        }
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {

        if (operator == msg.sender) {
            revert("ERC721: approve to caller");
        }
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner_, address operator) public view returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert("ERC721: caller is not token owner or approved");
        }
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert("ERC721: caller is not token owner or approved");
        }
        _safeTransfer(from, to, tokenId, data);
    }

    function mint(address to, uint256 quantity) public payable {

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (!mintingEnabled) {
            revert("Minting is not enabled");
        }

        if (_currentIndex + quantity > maxSupply + 1) {
            revert("Exceeds maximum supply");
        }

        if (mintedPerWallet[to] + quantity > maxPerWallet) {
            revert("Exceeds maximum per wallet");
        }

        if (msg.value < mintPrice * quantity) {
            revert("Insufficient payment");
        }

        mintedPerWallet[to] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _owners[tokenId] = to;
            tokenExists[tokenId] = true;
            _balances[to] += 1;
            emit Transfer(address(0), to, tokenId);
            _currentIndex++;
        }
    }

    function ownerMint(address to, uint256 quantity) public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (_currentIndex + quantity > maxSupply + 1) {
            revert("Exceeds maximum supply");
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _owners[tokenId] = to;
            tokenExists[tokenId] = true;
            _balances[to] += 1;
            emit Transfer(address(0), to, tokenId);
            _currentIndex++;
        }
    }

    function setMintingEnabled(bool enabled) public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        mintingEnabled = enabled;
        emit MintingToggled(enabled);
    }

    function setMintPrice(uint256 newPrice) public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        mintPrice = newPrice;
        emit PriceUpdated(newPrice);
    }

    function setMaxPerWallet(uint256 newMax) public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        maxPerWallet = newMax;
    }

    function setBaseURI(string memory newBaseURI) public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        baseTokenURI = newBaseURI;
    }

    function withdraw() public {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }

    function totalSupply() public view returns (uint256) {
        return _currentIndex - 1;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return tokenExists[tokenId];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {

        if (!tokenExists[tokenId]) {
            revert("ERC721: invalid token ID");
        }
        address owner_ = ownerOf(tokenId);
        return (spender == owner_ || isApprovedForAll(owner_, spender) || getApproved(tokenId) == spender);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {

        if (ownerOf(tokenId) != from) {
            revert("ERC721: transfer from incorrect owner");
        }

        if (to == address(0)) {
            revert("ERC721: transfer to the zero address");
        }

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);

        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert("ERC721: transfer to non ERC721Receiver implementer");
        }
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
