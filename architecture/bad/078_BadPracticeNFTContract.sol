
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

interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract BadPracticeNFTContract is IERC165, IERC721, IERC721Metadata {
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    string internal _name;
    string internal _symbol;
    mapping(uint256 => string) internal _tokenURIs;

    address public owner;
    uint256 public totalSupply;
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public mintingActive;

    constructor() {
        _name = "BadPracticeNFT";
        _symbol = "BPNFT";
        owner = msg.sender;
        totalSupply = 0;
        maxSupply = 10000;
        mintPrice = 0.01 ether;
        mintingActive = true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address ownerAddr) public view virtual override returns (uint256) {

        if (ownerAddr == address(0)) {
            revert("ERC721: address zero is not a valid owner");
        }
        return _balances[ownerAddr];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {

        if (!_exists(tokenId)) {
            revert("ERC721: invalid token ID");
        }
        return _owners[tokenId];
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {

        if (!_exists(tokenId)) {
            revert("ERC721: invalid token ID");
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return bytes(base).length > 0 ? string(abi.encodePacked(base, _toString(tokenId))) : "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address ownerAddr = ownerOf(tokenId);

        if (to == ownerAddr) {
            revert("ERC721: approval to current owner");
        }

        if (msg.sender != ownerAddr && !isApprovedForAll(ownerAddr, msg.sender)) {
            revert("ERC721: approve caller is not token owner or approved for all");
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {

        if (!_exists(tokenId)) {
            revert("ERC721: invalid token ID");
        }

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {

        if (operator == msg.sender) {
            revert("ERC721: approve to caller");
        }

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address ownerAddr, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[ownerAddr][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert("ERC721: caller is not token owner or approved");
        }

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert("ERC721: caller is not token owner or approved");
        }
        _safeTransfer(from, to, tokenId, data);
    }


    function mint(address to, string memory uri) public payable {

        if (msg.sender != owner) {

            if (!mintingActive) {
                revert("Minting is not active");
            }

            if (msg.value < 0.01 ether) {
                revert("Insufficient payment");
            }
        }


        if (to == address(0)) {
            revert("ERC721: mint to the zero address");
        }

        if (totalSupply >= 10000) {
            revert("Max supply reached");
        }

        uint256 tokenId = totalSupply + 1;
        totalSupply++;

        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = uri;

        emit Transfer(address(0), to, tokenId);
    }


    function batchMint(address[] memory recipients, string[] memory uris) public {

        if (msg.sender != owner) {
            revert("Only owner can batch mint");
        }

        if (recipients.length != uris.length) {
            revert("Arrays length mismatch");
        }

        for (uint256 i = 0; i < recipients.length; i++) {

            if (recipients[i] == address(0)) {
                revert("ERC721: mint to the zero address");
            }

            if (totalSupply >= 10000) {
                revert("Max supply reached");
            }

            uint256 tokenId = totalSupply + 1;
            totalSupply++;

            _balances[recipients[i]] += 1;
            _owners[tokenId] = recipients[i];
            _tokenURIs[tokenId] = uris[i];

            emit Transfer(address(0), recipients[i], tokenId);
        }
    }


    function setBaseURI(string memory newBaseURI) public {

        if (msg.sender != owner) {
            revert("Only owner can set base URI");
        }
        _baseTokenURI = newBaseURI;
    }


    function setMintPrice(uint256 newPrice) public {

        if (msg.sender != owner) {
            revert("Only owner can set mint price");
        }
        mintPrice = newPrice;
    }


    function toggleMinting() public {

        if (msg.sender != owner) {
            revert("Only owner can toggle minting");
        }
        mintingActive = !mintingActive;
    }


    function withdraw() public {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        uint256 balance = address(this).balance;

        if (balance == 0) {
            revert("No funds to withdraw");
        }

        (bool success, ) = payable(owner).call{value: balance}("");

        if (!success) {
            revert("Withdrawal failed");
        }
    }


    function transferOwnership(address newOwner) public {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }

        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }
        owner = newOwner;
    }


    string internal _baseTokenURI;

    function _baseURI() internal view returns (string memory) {
        return _baseTokenURI;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {

        if (!_exists(tokenId)) {
            revert("ERC721: invalid token ID");
        }
        address ownerAddr = ownerOf(tokenId);
        return (spender == ownerAddr || isApprovedForAll(ownerAddr, spender) || getApproved(tokenId) == spender);
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


    function _toString(uint256 value) internal pure returns (string memory) {
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


    bool public paused = false;

    function pause() public {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }
        paused = true;
    }

    function unpause() public {

        if (msg.sender != owner) {
            revert("Only owner can unpause");
        }
        paused = false;
    }


    function transferFrom(address from, address to, uint256 tokenId, bool bypassPause) public {

        if (paused && !bypassPause) {
            revert("Contract is paused");
        }

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert("ERC721: caller is not token owner or approved");
        }

        _transfer(from, to, tokenId);
    }
}
