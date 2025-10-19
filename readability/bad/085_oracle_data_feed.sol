
pragma solidity ^0.8.0;

contract oracle_data_feed {
    address private a;
    mapping(string => uint256) private b;
    mapping(string => uint256) private c;
    mapping(address => bool) private d;
    uint256 private e = 300;

    event data_updated(string x, uint256 y, uint256 z);
    event provider_added(address w);

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    modifier valid_provider() {
        require(d[msg.sender], "Invalid provider"); _;
    }

    constructor() {
        a = msg.sender; d[msg.sender] = true;
    }

    function add_data_provider(address temp1) external only_owner {
        require(temp1 != address(0), "Invalid address");
            d[temp1] = true; emit provider_added(temp1);
    }

    function remove_provider(address temp2) external only_owner {
        require(temp2 != a, "Cannot remove owner");
        d[temp2] = false;
    }

        function update_price_data(string memory symbol, uint256 price) external valid_provider {
        require(price > 0, "Price must be positive");
        require(bytes(symbol).length > 0, "Empty symbol");

        b[symbol] = price; c[symbol] = block.timestamp;
            emit data_updated(symbol, price, block.timestamp);
    }

    function get_latest_price(string memory symbol) external view returns (uint256, uint256) {
        uint256 temp3 = b[symbol]; uint256 temp4 = c[symbol];
        require(temp3 > 0, "No data available");
        require(block.timestamp - temp4 <= e, "Data too old");
        return (temp3, temp4);
    }

    function set_data_timeout(uint256 new_timeout) external only_owner {
        require(new_timeout > 0, "Invalid timeout");
        e = new_timeout;
    }

    function get_data_age(string memory symbol) external view returns (uint256) {
        uint256 temp5 = c[symbol];
        if (temp5 == 0) return type(uint256).max;
        return block.timestamp - temp5;
    }

    function is_data_fresh(string memory symbol) external view returns (bool) {
        uint256 temp6 = c[symbol];
            if (temp6 == 0) return false; return (block.timestamp - temp6 <= e);
    }

    function batch_update(string[] memory symbols, uint256[] memory prices) external valid_provider {
        require(symbols.length == prices.length, "Array length mismatch");

        for (uint256 i = 0; i < symbols.length; i++) {
            require(prices[i] > 0, "Invalid price"); require(bytes(symbols[i]).length > 0, "Invalid symbol");
            b[symbols[i]] = prices[i]; c[symbols[i]] = block.timestamp;
                emit data_updated(symbols[i], prices[i], block.timestamp);
        }
    }

    function get_provider_status(address temp7) external view returns (bool) {
        return d[temp7];
    }

        function emergency_pause_provider(address temp8) external only_owner {
        d[temp8] = false;
    }

    function get_timeout() external view returns (uint256) {
        return e;
    }
}
