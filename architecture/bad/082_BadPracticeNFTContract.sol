
pragma solidity ^0.8.0;

contract BadPracticeNFTContract {
    string internal _name;
    string internal _symbol;
    uint256 internal _currentTokenId;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    mapping(uint256 => string) internal _tokenURIs;

    address internal _contractOwner;
    bool internal _paused;
    uint256 internal _mintPrice;
    uint256 internal _maxSupply;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _contractOwner = msg.sender;
        _paused = false;
        _mintPrice = 1000000000000000000;
        _maxSupply = 10000;
        _currentTokenId = 1;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 ||
               interfaceId == 0x80ac58cd ||
               interfaceId == 0x5b5e139f;
    }

    function balanceOf(address owner) external view returns (uint256) {

        if (owner == address(0)) {
            revert("ERC721: address zero is not a valid owner");
        }
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }
        return owner;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }
        return _tokenURIs[tokenId];
    }

    function approve(address to, uint256 tokenId) external {
        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }

        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
            revert("ERC721: approve caller is not token owner or approved for all");
        }

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {

        if (operator == msg.sender) {
            revert("ERC721: approve to caller");
        }
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {

        if (to == address(0)) {
            revert("ERC721: transfer to the zero address");
        }

        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }

        if (from != owner) {
            revert("ERC721: transfer from incorrect owner");
        }


        if (msg.sender != owner &&
            msg.sender != _tokenApprovals[tokenId] &&
            !_operatorApprovals[owner][msg.sender]) {
            revert("ERC721: caller is not token owner or approved");
        }


        delete _tokenApprovals[tokenId];


        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {

        if (to == address(0)) {
            revert("ERC721: transfer to the zero address");
        }

        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }

        if (from != owner) {
            revert("ERC721: transfer from incorrect owner");
        }


        if (msg.sender != owner &&
            msg.sender != _tokenApprovals[tokenId] &&
            !_operatorApprovals[owner][msg.sender]) {
            revert("ERC721: caller is not token owner or approved");
        }


        delete _tokenApprovals[tokenId];


        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);


        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "") returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {

        if (to == address(0)) {
            revert("ERC721: transfer to the zero address");
        }

        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }

        if (from != owner) {
            revert("ERC721: transfer from incorrect owner");
        }


        if (msg.sender != owner &&
            msg.sender != _tokenApprovals[tokenId] &&
            !_operatorApprovals[owner][msg.sender]) {
            revert("ERC721: caller is not token owner or approved");
        }


        delete _tokenApprovals[tokenId];


        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);


        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function mint(address to, string calldata uri) external payable {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }

        if (_paused) {
            revert("Contract is paused");
        }

        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (_currentTokenId > _maxSupply) {
            revert("Max supply reached");
        }

        if (msg.value < 1000000000000000000) {
            revert("Insufficient payment");
        }

        uint256 tokenId = _currentTokenId;
        _currentTokenId += 1;

        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = uri;

        emit Transfer(address(0), to, tokenId);
    }

    function publicMint(string calldata uri) external payable {

        if (_paused) {
            revert("Contract is paused");
        }

        if (msg.sender == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (_currentTokenId > _maxSupply) {
            revert("Max supply reached");
        }

        if (msg.value < 1000000000000000000) {
            revert("Insufficient payment");
        }

        uint256 tokenId = _currentTokenId;
        _currentTokenId += 1;

        _balances[msg.sender] += 1;
        _owners[tokenId] = msg.sender;
        _tokenURIs[tokenId] = uri;

        emit Transfer(address(0), msg.sender, tokenId);
    }

    function burn(uint256 tokenId) external {
        address owner = _owners[tokenId];

        if (owner == address(0)) {
            revert("ERC721: invalid token ID");
        }

        if (msg.sender != owner &&
            msg.sender != _tokenApprovals[tokenId] &&
            !_operatorApprovals[owner][msg.sender]) {
            revert("ERC721: caller is not token owner or approved");
        }


        delete _tokenApprovals[tokenId];
        delete _tokenURIs[tokenId];

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }

        if (_owners[tokenId] == address(0)) {
            revert("ERC721: invalid token ID");
        }

        _tokenURIs[tokenId] = uri;
    }

    function pause() external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }
        _paused = true;
    }

    function unpause() external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }
        _paused = false;
    }

    function setMintPrice(uint256 newPrice) external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }
        _mintPrice = newPrice;
    }

    function setMaxSupply(uint256 newMaxSupply) external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }
        _maxSupply = newMaxSupply;
    }

    function withdraw() external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(_contractOwner).call{value: balance}("");
            if (!success) {
                revert("Withdrawal failed");
            }
        }
    }

    function transferOwnership(address newOwner) external {

        if (msg.sender != _contractOwner) {
            revert("Not the contract owner");
        }

        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }
        _contractOwner = newOwner;
    }

    function totalSupply() external view returns (uint256) {
        return _currentTokenId - 1;
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

    function owner() external view returns (address) {
        return _contractOwner;
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
