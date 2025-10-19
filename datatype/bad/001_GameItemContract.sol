
pragma solidity ^0.8.0;

contract GameItemContract {
    struct GameItem {
        uint256 itemId;
        string itemType;
        uint256 rarity;
        uint256 durability;
        uint256 isEquipped;
        bytes metadata;
        uint256 isForSale;
        uint256 price;
        address owner;
    }

    mapping(uint256 => GameItem) public items;
    mapping(address => uint256[]) public playerItems;

    uint256 public nextItemId;
    uint256 public totalItems;
    address public contractOwner;

    event ItemCreated(uint256 itemId, address owner, string itemType);
    event ItemTransferred(uint256 itemId, address from, address to);
    event ItemEquipped(uint256 itemId, address player);
    event ItemListed(uint256 itemId, uint256 price);

    constructor() {
        contractOwner = msg.sender;
        nextItemId = uint256(1);
    }

    function createItem(
        string memory _itemType,
        uint256 _rarity,
        bytes memory _metadata
    ) public {
        require(_rarity >= uint256(1) && _rarity <= uint256(5), "Invalid rarity");

        uint256 newItemId = nextItemId;

        items[newItemId] = GameItem({
            itemId: newItemId,
            itemType: _itemType,
            rarity: _rarity,
            durability: uint256(100),
            isEquipped: uint256(0),
            metadata: _metadata,
            isForSale: uint256(0),
            price: uint256(0),
            owner: msg.sender
        });

        playerItems[msg.sender].push(newItemId);

        nextItemId = nextItemId + uint256(1);
        totalItems = totalItems + uint256(1);

        emit ItemCreated(newItemId, msg.sender, _itemType);
    }

    function equipItem(uint256 _itemId) public {
        require(items[_itemId].owner == msg.sender, "Not your item");
        require(items[_itemId].isEquipped == uint256(0), "Already equipped");

        items[_itemId].isEquipped = uint256(1);

        emit ItemEquipped(_itemId, msg.sender);
    }

    function unequipItem(uint256 _itemId) public {
        require(items[_itemId].owner == msg.sender, "Not your item");
        require(items[_itemId].isEquipped == uint256(1), "Not equipped");

        items[_itemId].isEquipped = uint256(0);
    }

    function listItemForSale(uint256 _itemId, uint256 _price) public {
        require(items[_itemId].owner == msg.sender, "Not your item");
        require(_price > uint256(0), "Price must be positive");
        require(items[_itemId].isEquipped == uint256(0), "Cannot sell equipped item");

        items[_itemId].isForSale = uint256(1);
        items[_itemId].price = _price;

        emit ItemListed(_itemId, _price);
    }

    function removeFromSale(uint256 _itemId) public {
        require(items[_itemId].owner == msg.sender, "Not your item");

        items[_itemId].isForSale = uint256(0);
        items[_itemId].price = uint256(0);
    }

    function buyItem(uint256 _itemId) public payable {
        require(items[_itemId].isForSale == uint256(1), "Item not for sale");
        require(msg.value >= items[_itemId].price, "Insufficient payment");
        require(items[_itemId].owner != msg.sender, "Cannot buy your own item");

        address seller = items[_itemId].owner;


        _removeItemFromPlayer(seller, _itemId);


        items[_itemId].owner = msg.sender;
        items[_itemId].isForSale = uint256(0);
        items[_itemId].price = uint256(0);
        items[_itemId].isEquipped = uint256(0);

        playerItems[msg.sender].push(_itemId);


        payable(seller).transfer(msg.value);

        emit ItemTransferred(_itemId, seller, msg.sender);
    }

    function repairItem(uint256 _itemId) public payable {
        require(items[_itemId].owner == msg.sender, "Not your item");
        require(items[_itemId].durability < uint256(100), "Item already at full durability");
        require(msg.value >= uint256(1000000000000000), "Insufficient repair fee");

        items[_itemId].durability = uint256(100);
    }

    function getPlayerItems(address _player) public view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) public view returns (
        uint256,
        string memory,
        uint256,
        uint256,
        uint256,
        bytes memory,
        uint256,
        uint256,
        address
    ) {
        GameItem memory item = items[_itemId];
        return (
            item.itemId,
            item.itemType,
            item.rarity,
            item.durability,
            item.isEquipped,
            item.metadata,
            item.isForSale,
            item.price,
            item.owner
        );
    }

    function _removeItemFromPlayer(address _player, uint256 _itemId) private {
        uint256[] storage playerItemList = playerItems[_player];
        for (uint256 i = uint256(0); i < playerItemList.length; i = i + uint256(1)) {
            if (playerItemList[i] == _itemId) {
                playerItemList[i] = playerItemList[playerItemList.length - uint256(1)];
                playerItemList.pop();
                break;
            }
        }
    }

    function withdrawFees() public {
        require(msg.sender == contractOwner, "Only owner can withdraw");
        payable(contractOwner).transfer(address(this).balance);
    }
}
