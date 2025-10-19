
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeePercent = 5;
    address public owner;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");

        uint256 campaignId = campaignCounter++;
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.creator = msg.sender;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.deadline = block.timestamp + (_durationDays * 1 days);
        newCampaign.isActive = true;

        emit CampaignCreated(campaignId, msg.sender, _title, _goalAmount, newCampaign.deadline);
        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        campaignActive(_campaignId)
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender != campaign.creator, "Creator cannot contribute to own campaign");

        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;

        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw funds");
        require(block.timestamp >= campaign.deadline, "Campaign has not ended yet");
        require(campaign.goalReached, "Goal not reached");
        require(campaign.isActive, "Campaign already processed");

        campaign.isActive = false;

        uint256 platformFee = _calculatePlatformFee(campaign.raisedAmount);
        uint256 creatorAmount = campaign.raisedAmount - platformFee;

        _transferFunds(payable(campaign.creator), creatorAmount);
        _transferFunds(payable(owner), platformFee);

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }

    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign has not ended yet");
        require(!campaign.goalReached, "Goal was reached, no refund available");

        uint256 contributionAmount = campaign.contributions[msg.sender];
        require(contributionAmount > 0, "No contribution found");

        campaign.contributions[msg.sender] = 0;
        campaign.raisedAmount -= contributionAmount;

        _transferFunds(payable(msg.sender), contributionAmount);

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (
            address creator,
            string memory title,
            uint256 goalAmount,
            uint256 raisedAmount
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.goalAmount,
            campaign.raisedAmount
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function setCampaignInactive(uint256 _campaignId)
        external
        validCampaign(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            msg.sender == campaign.creator || msg.sender == owner,
            "Only creator or owner can deactivate campaign"
        );

        campaign.isActive = false;
    }

    function updatePlatformFee(uint256 _newFeePercent)
        external
        onlyOwner
    {
        require(_newFeePercent <= 10, "Fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }

    function _calculatePlatformFee(uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return (_amount * platformFeePercent) / 100;
    }

    function _transferFunds(address payable _to, uint256 _amount)
        internal
    {
        require(_amount > 0, "Transfer amount must be greater than 0");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }
}
