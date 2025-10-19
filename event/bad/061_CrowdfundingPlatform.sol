
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
        string title;
        string description;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(address => uint256[]) public userCampaigns;

    uint256 public campaignCounter;
    uint256 public platformFee = 25;
    address public owner;

    error InvalidInput();
    error NotAuthorized();
    error Failed();

    event CampaignCreated(uint256 campaignId, address creator, uint256 goal);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event CampaignCompleted(uint256 campaignId);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        uint256 _goal,
        uint256 _duration,
        string memory _title,
        string memory _description
    ) external {
        require(_goal > 0);
        require(_duration > 0);
        require(bytes(_title).length > 0);

        uint256 campaignId = campaignCounter++;
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + _duration,
            completed: false,
            withdrawn: false,
            title: _title,
            description: _description
        });

        userCampaigns[msg.sender].push(campaignId);
        emit CampaignCreated(campaignId, msg.sender, _goal);
    }

    function contribute(uint256 _campaignId) external payable validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline);
        require(msg.value > 0);
        require(!campaign.completed);

        contributions[_campaignId][msg.sender] += msg.value;
        campaign.raised += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value);

        if (campaign.raised >= campaign.goal) {
            campaign.completed = true;
            emit CampaignCompleted(_campaignId);
        }
    }

    function withdrawFunds(uint256 _campaignId) external validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator);
        require(campaign.completed);
        require(!campaign.withdrawn);

        uint256 amount = campaign.raised;
        uint256 fee = (amount * platformFee) / 1000;
        uint256 creatorAmount = amount - fee;

        campaign.withdrawn = true;

        (bool success1, ) = payable(campaign.creator).call{value: creatorAmount}("");
        require(success1);

        (bool success2, ) = payable(owner).call{value: fee}("");
        require(success2);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function refund(uint256 _campaignId) external validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline);
        require(!campaign.completed);

        uint256 contributedAmount = contributions[_campaignId][msg.sender];
        require(contributedAmount > 0);

        contributions[_campaignId][msg.sender] = 0;
        campaign.raised -= contributedAmount;

        (bool success, ) = payable(msg.sender).call{value: contributedAmount}("");
        require(success);
    }

    function getCampaign(uint256 _campaignId) external view validCampaign(_campaignId) returns (
        address creator,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool completed,
        bool withdrawn,
        string memory title,
        string memory description
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.withdrawn,
            campaign.title,
            campaign.description
        );
    }

    function getUserCampaigns(address _user) external view returns (uint256[] memory) {
        return userCampaigns[_user];
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }

    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100);
        platformFee = _fee;
    }

    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success);
    }
}
