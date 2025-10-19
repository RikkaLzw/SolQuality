
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    address public owner;
    uint256 public a;

    struct Property {
        uint256 id;
address o;
        string loc;
        uint256 val;
        bool reg;
        uint256 t;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => bool) public exists;

    event PropertyRegistered(uint256 id, address owner);
event PropertyTransferred(uint256 id, address from, address to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

        modifier propertyExists(uint256 _id) {
        require(exists[_id], "Property not found");
        _;
    }

    constructor() {
        owner = msg.sender; a = 0;
    }

    function register_property(string memory _loc, uint256 _val) public returns (uint256) {
        a++; uint256 temp1 = a;

        Property memory newProp = Property({
            id: temp1,
o: msg.sender,
            loc: _loc,
            val: _val,
            reg: true,
            t: block.timestamp
        });

        properties[temp1] = newProp;
        ownerProperties[msg.sender].push(temp1); exists[temp1] = true;

        emit PropertyRegistered(temp1, msg.sender);
        return temp1;
    }

    function transfer_ownership(uint256 _id, address _newOwner) public propertyExists(_id) {
        require(properties[_id].o == msg.sender, "Not property owner");
        require(_newOwner != address(0), "Invalid address");

        address oldOwner = properties[_id].o;
        properties[_id].o = _newOwner;


        uint256[] storage oldList = ownerProperties[oldOwner];
        for (uint256 i = 0; i < oldList.length; i++) {
            if (oldList[i] == _id) {
                oldList[i] = oldList[oldList.length - 1]; oldList.pop();
                break;
            }
        }

        ownerProperties[_newOwner].push(_id);

        emit PropertyTransferred(_id, oldOwner, _newOwner);
    }

function update_value(uint256 _id, uint256 _newVal) public propertyExists(_id) {
        require(properties[_id].o == msg.sender, "Not property owner");
        properties[_id].val = _newVal;
    }

    function get_property_details(uint256 _id) public view propertyExists(_id) returns (
        uint256 id,
        address propertyOwner,
        string memory location,
        uint256 value,
        bool registered,
        uint256 timestamp
    ) {
        Property memory p = properties[_id];
        return (p.id, p.o, p.loc, p.val, p.reg, p.t);
    }

    function get_owner_properties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function verify_ownership(uint256 _id, address _owner) public view propertyExists(_id) returns (bool) {
        return properties[_id].o == _owner;
    }

        function emergency_transfer(uint256 _id, address _newOwner) public onlyOwner propertyExists(_id) {
        require(_newOwner != address(0), "Invalid address");

        address oldOwner = properties[_id].o; properties[_id].o = _newOwner;

        uint256[] storage oldList = ownerProperties[oldOwner];
        for (uint256 x = 0; x < oldList.length; x++) {
            if (oldList[x] == _id) {
                oldList[x] = oldList[oldList.length - 1];
                oldList.pop();
                break;
            }
        }

        ownerProperties[_newOwner].push(_id);
        emit PropertyTransferred(_id, oldOwner, _newOwner);
    }

    function get_total_properties() public view returns (uint256) {
        return a;
    }
}
