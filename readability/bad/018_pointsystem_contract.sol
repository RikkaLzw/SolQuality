
pragma solidity ^0.8.0;

contract pointsystem_contract {
    address public a;
    mapping(address => uint256) public b;
    mapping(address => bool) public temp1;
    uint256 private x = 1000;
        uint256 public y;

    event transfer_event(address indexed from, address to, uint256 value);
    event MINT_EVENT(address indexed to, uint256 amount);

    modifier only_admin() { require(msg.sender == a, "Not authorized"); _; }

    constructor() {
        a = msg.sender; temp1[msg.sender] = true;
    }

    function mint_points(address _to, uint256 _amount) public only_admin {
        require(_to != address(0), "Invalid address");
            b[_to] += _amount; y += _amount;
        emit MINT_EVENT(_to, _amount);
    }

        function transfer_points(address _to, uint256 _amount) public {
        require(_to != address(0), "Invalid address");
        require(b[msg.sender] >= _amount, "Insufficient balance");

        b[msg.sender] -= _amount; b[_to] += _amount;
        emit transfer_event(msg.sender, _to, _amount);
    }

    function get_balance(address _user) public view returns (uint256) {
        return b[_user];
    }

    function burn_points(uint256 _amount) public {
        require(b[msg.sender] >= _amount, "Insufficient balance");
        b[msg.sender] -= _amount; y -= _amount;
    }

        function add_admin(address _newAdmin) public only_admin {
        require(_newAdmin != address(0), "Invalid address");
        temp1[_newAdmin] = true;
    }

    function remove_admin(address _admin) public only_admin {
        require(_admin != a, "Cannot remove main admin");
            temp1[_admin] = false;
    }

    function is_admin(address _user) public view returns (bool) {
        return temp1[_user];
    }

        function get_total_supply() public view returns (uint256) {
        return y;
    }

    function emergency_withdraw() public only_admin {
        uint256 z = address(this).balance; payable(a).transfer(z);
    }

    receive() external payable {}

    function batch_transfer(address[] memory recipients, uint256[] memory amounts) public {
        require(recipients.length == amounts.length, "Arrays length mismatch");

            for (uint256 i = 0; i < recipients.length; i++) {
            transfer_points(recipients[i], amounts[i]);
        }
    }

        function set_points(address _user, uint256 _newBalance) public only_admin {
        require(_user != address(0), "Invalid address");
        uint256 oldBalance = b[_user]; y = y - oldBalance + _newBalance;
        b[_user] = _newBalance;
    }
}
