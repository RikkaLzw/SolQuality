
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
    address internal _contractOwner;
    bool internal _paused;
    uint256 internal _mintPrice;
    uint256 internal _maxSupply;
    mapping(address => bool) internal _whitelist;
    mapping(address => uint256) internal _mintedCount;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() {
        _name = "Bad Practice NFT Collection";
        _symbol = "BPNFT";
        _contractOwner = msg.sender;
        _currentIndex = 1;
        _mintPrice = 0.01 ether;
        _maxSupply = 10000;
        _paused = false;
    }

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address owner) public view returns (uint256) {

        if (owner == address(0)) {
            revert("ERC721: address zero is not a valid owner");
        }
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }
        return owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = "https://api.badpracticenft.com/metadata/";

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return string(abi.encodePacked(base, toString(tokenId)));
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);

        if (to == owner) {
            revert("ERC721: approval to current owner");
        }

        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert("ERC721: approve caller is not token owner or approved for all");
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {

        if (_owners[tokenId] == address(0)) {
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

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
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

        if (_paused) {
            revert("Contract is paused");
        }

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        if (_currentIndex + quantity > _maxSupply + 1) {
            revert("Exceeds maximum supply");
        }

        if (msg.value < _mintPrice * quantity) {
            revert("Insufficient payment");
        }

        if (_mintedCount[to] + quantity > 5) {
            revert("Exceeds per-address mint limit");
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _owners[tokenId] = to;
            _balances[to] += 1;
            _currentIndex += 1;
            emit Transfer(address(0), to, tokenId);
        }

        _mintedCount[to] += quantity;
    }


    function whitelistMint(address to, uint256 quantity) public payable {

        if (_paused) {
            revert("Contract is paused");
        }

        if (!_whitelist[msg.sender]) {
            revert("Not whitelisted");
        }

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        if (_currentIndex + quantity > _maxSupply + 1) {
            revert("Exceeds maximum supply");
        }

        if (msg.value < (_mintPrice * 80 / 100) * quantity) {
            revert("Insufficient payment");
        }

        if (_mintedCount[to] + quantity > 3) {
            revert("Exceeds whitelist mint limit");
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _owners[tokenId] = to;
            _balances[to] += 1;
            _currentIndex += 1;
            emit Transfer(address(0), to, tokenId);
        }

        _mintedCount[to] += quantity;
    }


    function ownerMint(address to, uint256 quantity) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        if (_currentIndex + quantity > _maxSupply + 1) {
            revert("Exceeds maximum supply");
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _owners[tokenId] = to;
            _balances[to] += 1;
            _currentIndex += 1;
            emit Transfer(address(0), to, tokenId);
        }
    }

    function setPaused(bool paused) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        _paused = paused;
    }

    function setMintPrice(uint256 newPrice) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        _mintPrice = newPrice;
    }

    function addToWhitelist(address[] memory addresses) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelist[addresses[i]] = true;
        }
    }

    function removeFromWhitelist(address[] memory addresses) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelist[addresses[i]] = false;
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }
        _tokenURIs[tokenId] = uri;
    }

    function withdraw() public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        uint256 balance = address(this).balance;

        if (balance == 0) {
            revert("No funds to withdraw");
        }

        (bool success, ) = payable(_contractOwner).call{value: balance}("");

        if (!success) {
            revert("Withdrawal failed");
        }
    }


    function totalSupply() external view returns (uint256) {
        return _currentIndex - 1;
    }

    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    function mintPrice() external view returns (uint256) {
        return _mintPrice;
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }

    function isWhitelisted(address addr) external view returns (bool) {
        return _whitelist[addr];
    }

    function mintedCount(address addr) external view returns (uint256) {
        return _mintedCount[addr];
    }

    function contractOwner() external view returns (address) {
        return _contractOwner;
    }


    function _exists(uint256 tokenId) public view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) public view returns (bool) {

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _approve(address to, uint256 tokenId) public {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) public {

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

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) public {
        _transfer(from, to, tokenId);

        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert("ERC721: transfer to non ERC721Receiver implementer");
        }
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) public returns (bool) {
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


    function toString(uint256 value) public pure returns (string memory) {
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


    function batchTransfer(address[] memory tos, uint256[] memory tokenIds) public {

        if (tos.length != tokenIds.length) {
            revert("Arrays length mismatch");
        }

        if (tos.length == 0) {
            revert("Empty arrays");
        }

        if (tos.length > 50) {
            revert("Too many transfers");
        }

        for (uint256 i = 0; i < tos.length; i++) {

            if (!_isApprovedOrOwner(msg.sender, tokenIds[i])) {
                revert("ERC721: caller is not token owner or approved");
            }
            _transfer(ownerOf(tokenIds[i]), tos[i], tokenIds[i]);
        }
    }


    function emergencyPause() public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }
        _paused = true;
    }

    function transferOwnership(address newOwner) public {

        if (msg.sender != _contractOwner) {
            revert("Only owner can call this function");
        }

        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }
        _contractOwner = newOwner;
    }


    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view returns (address receiver, uint256 royaltyAmount) {

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }
        receiver = _contractOwner;
        royaltyAmount = (salePrice * 250) / 10000;
    }


    receive() external payable {}
    fallback() external payable {}
}
