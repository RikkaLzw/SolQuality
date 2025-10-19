
pragma solidity ^0.8.0;

contract GameItemContract {
    address public owner;
    uint256 public totalItems;

    struct GameItem {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 power;
        address currentOwner;
        bool isActive;
    }

    mapping(uint256 => GameItem) public items;
    mapping(address => uint256[]) public playerItems;
    mapping(address => bool) public authorizedMinters;

    error E1();
    error E2();
    error E3();

    event ItemCreated(uint256 itemId, string name, uint256 rarity);
    event ItemTransferred(address from, address to, uint256 itemId);
    event ItemUpgraded(uint256 itemId, uint256 newPower);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedMinters[msg.sender] = true;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _power,
        address _to
    ) external onlyAuthorized {
        require(_rarity > 0 && _rarity <= 5);
        require(_power > 0);
        require(_to != address(0));

        totalItems++;
        uint256 itemId = totalItems;

        items[itemId] = GameItem({
            id: itemId,
            name: _name,
            rarity: _rarity,
            power: _power,
            currentOwner: _to,
            isActive: true
        });

        playerItems[_to].push(itemId);

        emit ItemCreated(itemId, _name, _rarity);
    }

    function transferItem(uint256 _itemId, address _to) external {
        require(_to != address(0));
        require(items[_itemId].currentOwner == msg.sender);
        require(items[_itemId].isActive);

        address from = msg.sender;
        items[_itemId].currentOwner = _to;


        uint256[] storage senderItems = playerItems[from];
        for (uint256 i = 0; i < senderItems.length; i++) {
            if (senderItems[i] == _itemId) {
                senderItems[i] = senderItems[senderItems.length - 1];
                senderItems.pop();
                break;
            }
        }

        playerItems[_to].push(_itemId);

        emit ItemTransferred(from, _to, _itemId);
    }

    function upgradeItem(uint256 _itemId, uint256 _additionalPower) external {
        require(items[_itemId].currentOwner == msg.sender);
        require(items[_itemId].isActive);
        require(_additionalPower > 0);

        items[_itemId].power += _additionalPower;

        emit ItemUpgraded(_itemId, items[_itemId].power);
    }

    function deactivateItem(uint256 _itemId) external onlyOwner {
        require(items[_itemId].id != 0);

        items[_itemId].isActive = false;

    }

    function addAuthorizedMinter(address _minter) external onlyOwner {
        require(_minter != address(0));

        authorizedMinters[_minter] = true;

    }

    function removeAuthorizedMinter(address _minter) external onlyOwner {
        require(_minter != address(0));

        authorizedMinters[_minter] = false;

    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        owner = _newOwner;

    }

    function batchTransfer(uint256[] memory _itemIds, address _to) external {
        require(_to != address(0));

        for (uint256 i = 0; i < _itemIds.length; i++) {
            if (items[_itemIds[i]].currentOwner != msg.sender) {
                revert E1();
            }
            if (!items[_itemIds[i]].isActive) {
                revert E2();
            }
        }

        for (uint256 i = 0; i < _itemIds.length; i++) {
            uint256 itemId = _itemIds[i];
            items[itemId].currentOwner = _to;


            uint256[] storage senderItems = playerItems[msg.sender];
            for (uint256 j = 0; j < senderItems.length; j++) {
                if (senderItems[j] == itemId) {
                    senderItems[j] = senderItems[senderItems.length - 1];
                    senderItems.pop();
                    break;
                }
            }

            playerItems[_to].push(itemId);
            emit ItemTransferred(msg.sender, _to, itemId);
        }
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) external view returns (GameItem memory) {
        require(items[_itemId].id != 0);
        return items[_itemId];
    }

    function isItemActive(uint256 _itemId) external view returns (bool) {
        return items[_itemId].isActive;
    }
}
