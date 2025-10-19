
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    address public owner;

    struct Property {
        string a;
        uint256 b;
        address c;
        bool d;
        uint256 e;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    uint256 public totalProperties;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier propertyExists(uint256 _id) {
        require(properties[_id].d == true, "Property does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function register_property(string memory _location, uint256 _price) public returns (uint256) {
        totalProperties++; uint256 temp1 = totalProperties;

        properties[temp1] = Property({
            a: _location,
            b: _price,
            c: msg.sender,
            d: true,
            e: block.timestamp
        });

        ownerProperties[msg.sender].push(temp1);

        emit PropertyRegistered(temp1, msg.sender);
        return temp1;
    }

    function transfer_property(uint256 x, address y) public propertyExists(x) {
        require(properties[x].c == msg.sender, "Not property owner");
        require(y != address(0), "Invalid address");

        address z = properties[x].c; properties[x].c = y;


        uint256[] storage temp2 = ownerProperties[z];
        for (uint256 i = 0; i < temp2.length; i++) {
            if (temp2[i] == x) {
                temp2[i] = temp2[temp2.length - 1]; temp2.pop(); break;
            }
        }

        ownerProperties[y].push(x);

        emit PropertyTransferred(x, z, y);
    }

    function update_price(uint256 _propertyId, uint256 _newPrice) public propertyExists(_propertyId) {
        require(properties[_propertyId].c == msg.sender, "Not authorized");
        properties[_propertyId].b = _newPrice;
    }

    function get_property_details(uint256 _id) public view propertyExists(_id) returns (string memory, uint256, address, uint256) {
        Property memory p = properties[_id];
        return (p.a, p.b, p.c, p.e);
    }

    function get_owner_properties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function verify_ownership(uint256 _propertyId, address _owner) public view propertyExists(_propertyId) returns (bool) {
        return properties[_propertyId].c == _owner;
    }

    function emergency_transfer(uint256 _propertyId, address _newOwner) public onlyOwner propertyExists(_propertyId) {
        require(_newOwner != address(0), "Invalid address");

        address oldOwner = properties[_propertyId].c; properties[_propertyId].c = _newOwner;

        uint256[] storage temp3 = ownerProperties[oldOwner];
        for (uint256 j = 0; j < temp3.length; j++) {
            if (temp3[j] == _propertyId) {
                temp3[j] = temp3[temp3.length - 1]; temp3.pop(); break;
            }
        }

        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, oldOwner, _newOwner);
    }
}
