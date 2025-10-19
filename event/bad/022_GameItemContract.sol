
pragma solidity ^0.8.0;

contract GameItemContract {
    mapping(address => mapping(uint256 => uint256)) public playerItems;
    mapping(uint256 => ItemInfo) public items;
    mapping(address => bool) public authorized;

    address public owner;
    uint256 public nextItemId;

    struct ItemInfo {
        string name;
        uint256 rarity;
        uint256 power;
        bool exists;
    }

    error Error1();
    error Error2();
    error Error3();

    event ItemCreated(uint256 itemId, string name);
    event ItemTransferred(address from, address to, uint256 itemId);
    event AuthorizedChanged(address account, bool status);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
        nextItemId = 1;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _power
    ) external onlyAuthorized {
        require(_rarity > 0 && _rarity <= 5);
        require(_power > 0);

        uint256 itemId = nextItemId;
        items[itemId] = ItemInfo({
            name: _name,
            rarity: _rarity,
            power: _power,
            exists: true
        });

        nextItemId++;

        emit ItemCreated(itemId, _name);
    }

    function mintItem(address _to, uint256 _itemId, uint256 _amount) external onlyAuthorized {
        require(_to != address(0));
        require(items[_itemId].exists);
        require(_amount > 0);

        playerItems[_to][_itemId] += _amount;
    }

    function transferItem(
        address _to,
        uint256 _itemId,
        uint256 _amount
    ) external {
        require(_to != address(0));
        require(_to != msg.sender);
        require(playerItems[msg.sender][_itemId] >= _amount);

        playerItems[msg.sender][_itemId] -= _amount;
        playerItems[_to][_itemId] += _amount;

        emit ItemTransferred(msg.sender, _to, _itemId);
    }

    function burnItem(uint256 _itemId, uint256 _amount) external {
        require(playerItems[msg.sender][_itemId] >= _amount);

        playerItems[msg.sender][_itemId] -= _amount;
    }

    function upgradeItem(uint256 _itemId) external {
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] >= 2);

        if (items[_itemId].rarity >= 5) {
            revert Error1();
        }

        playerItems[msg.sender][_itemId] -= 2;
        items[_itemId].power += 10;
        items[_itemId].rarity++;
    }

    function setAuthorized(address _account, bool _status) external onlyOwner {
        require(_account != address(0));

        authorized[_account] = _status;
        emit AuthorizedChanged(_account, _status);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        owner = _newOwner;
    }

    function getPlayerItemBalance(address _player, uint256 _itemId) external view returns (uint256) {
        return playerItems[_player][_itemId];
    }

    function getItemInfo(uint256 _itemId) external view returns (ItemInfo memory) {
        require(items[_itemId].exists);
        return items[_itemId];
    }

    function batchTransferItems(
        address _to,
        uint256[] calldata _itemIds,
        uint256[] calldata _amounts
    ) external {
        require(_to != address(0));
        require(_itemIds.length == _amounts.length);

        for (uint256 i = 0; i < _itemIds.length; i++) {
            if (playerItems[msg.sender][_itemIds[i]] < _amounts[i]) {
                revert Error2();
            }
            playerItems[msg.sender][_itemIds[i]] -= _amounts[i];
            playerItems[_to][_itemIds[i]] += _amounts[i];
        }
    }

    function combineItems(uint256 _itemId1, uint256 _itemId2) external {
        require(items[_itemId1].exists && items[_itemId2].exists);
        require(playerItems[msg.sender][_itemId1] >= 1);
        require(playerItems[msg.sender][_itemId2] >= 1);

        if (_itemId1 == _itemId2) {
            revert Error3();
        }

        playerItems[msg.sender][_itemId1] -= 1;
        playerItems[msg.sender][_itemId2] -= 1;

        uint256 newItemId = nextItemId;
        nextItemId++;

        items[newItemId] = ItemInfo({
            name: "Combined Item",
            rarity: (items[_itemId1].rarity + items[_itemId2].rarity) / 2,
            power: items[_itemId1].power + items[_itemId2].power,
            exists: true
        });

        playerItems[msg.sender][newItemId] = 1;
    }
}
