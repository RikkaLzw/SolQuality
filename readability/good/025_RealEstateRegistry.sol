
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct RealEstate {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 propertyArea;
        uint256 propertyValue;
        address currentOwner;
        address previousOwner;
        uint256 registrationDate;
        uint256 lastTransferDate;
        bool isActive;
        string additionalInfo;
    }


    struct TransferRecord {
        uint256 propertyId;
        address fromOwner;
        address toOwner;
        uint256 transferPrice;
        uint256 transferDate;
        string transferReason;
    }


    address public contractOwner;
    uint256 public totalProperties;
    uint256 public registrationFee;


    mapping(uint256 => RealEstate) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => TransferRecord[]) public transferHistory;
    mapping(address => bool) public authorizedOfficials;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 registrationDate
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferPrice,
        uint256 transferDate
    );

    event OwnershipChanged(
        uint256 indexed propertyId,
        address indexed newOwner,
        address indexed previousOwner
    );

    event OfficialAuthorized(
        address indexed official,
        bool authorized
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "只有合约所有者可以执行此操作");
        _;
    }

    modifier onlyAuthorizedOfficial() {
        require(
            msg.sender == contractOwner || authorizedOfficials[msg.sender],
            "只有授权官员可以执行此操作"
        );
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            properties[_propertyId].currentOwner == msg.sender,
            "只有房产所有者可以执行此操作"
        );
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isActive, "房产不存在或已失效");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "地址不能为零地址");
        _;
    }


    constructor(uint256 _registrationFee) {
        contractOwner = msg.sender;
        registrationFee = _registrationFee;
        totalProperties = 0;
    }


    function registerProperty(
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _propertyArea,
        uint256 _propertyValue,
        address _owner,
        string memory _additionalInfo
    )
        external
        payable
        onlyAuthorizedOfficial
        validAddress(_owner)
    {
        require(msg.value >= registrationFee, "登记费用不足");
        require(bytes(_propertyAddress).length > 0, "房产地址不能为空");
        require(_propertyArea > 0, "房产面积必须大于0");
        require(_propertyValue > 0, "房产价值必须大于0");

        totalProperties++;
        uint256 newPropertyId = totalProperties;


        properties[newPropertyId] = RealEstate({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            propertyArea: _propertyArea,
            propertyValue: _propertyValue,
            currentOwner: _owner,
            previousOwner: address(0),
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp,
            isActive: true,
            additionalInfo: _additionalInfo
        });


        ownerProperties[_owner].push(newPropertyId);


        emit PropertyRegistered(newPropertyId, _owner, _propertyAddress, block.timestamp);
    }


    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice,
        string memory _transferReason
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        validAddress(_newOwner)
    {
        require(_newOwner != msg.sender, "不能转让给自己");
        require(_transferPrice > 0, "转让价格必须大于0");
        require(bytes(_transferReason).length > 0, "转让原因不能为空");

        RealEstate storage property = properties[_propertyId];
        address previousOwner = property.currentOwner;


        property.previousOwner = previousOwner;
        property.currentOwner = _newOwner;
        property.lastTransferDate = block.timestamp;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        transferHistory[_propertyId].push(TransferRecord({
            propertyId: _propertyId,
            fromOwner: previousOwner,
            toOwner: _newOwner,
            transferPrice: _transferPrice,
            transferDate: block.timestamp,
            transferReason: _transferReason
        }));


        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, _transferPrice, block.timestamp);
        emit OwnershipChanged(_propertyId, _newOwner, previousOwner);
    }


    function updatePropertyInfo(
        uint256 _propertyId,
        uint256 _propertyValue,
        string memory _additionalInfo
    )
        external
        propertyExists(_propertyId)
        onlyAuthorizedOfficial
    {
        require(_propertyValue > 0, "房产价值必须大于0");

        RealEstate storage property = properties[_propertyId];
        property.propertyValue = _propertyValue;
        property.additionalInfo = _additionalInfo;
    }


    function setAuthorizedOfficial(address _official, bool _authorized)
        external
        onlyContractOwner
        validAddress(_official)
    {
        authorizedOfficials[_official] = _authorized;
        emit OfficialAuthorized(_official, _authorized);
    }


    function setRegistrationFee(uint256 _newFee)
        external
        onlyContractOwner
    {
        registrationFee = _newFee;
    }


    function deactivateProperty(uint256 _propertyId)
        external
        propertyExists(_propertyId)
        onlyAuthorizedOfficial
    {
        properties[_propertyId].isActive = false;
    }


    function getPropertyDetails(uint256 _propertyId)
        external
        view
        returns (RealEstate memory)
    {
        require(_propertyId > 0 && _propertyId <= totalProperties, "无效的房产ID");
        return properties[_propertyId];
    }


    function getOwnerProperties(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerProperties[_owner];
    }


    function getTransferHistory(uint256 _propertyId)
        external
        view
        returns (TransferRecord[] memory)
    {
        return transferHistory[_propertyId];
    }


    function withdrawFunds()
        external
        onlyContractOwner
    {
        uint256 balance = address(this).balance;
        require(balance > 0, "合约余额为0");

        (bool success, ) = payable(contractOwner).call{value: balance}("");
        require(success, "提取失败");
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId)
        private
    {
        uint256[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }


    function isAuthorizedOfficial(address _address)
        external
        view
        returns (bool)
    {
        return _address == contractOwner || authorizedOfficials[_address];
    }


    function getContractInfo()
        external
        view
        returns (address, uint256, uint256)
    {
        return (contractOwner, totalProperties, registrationFee);
    }
}
