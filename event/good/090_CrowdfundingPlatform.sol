
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
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
    uint256 public platformFeePercentage = 250;
    address payable public platformOwner;

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
        uint256 amount,
        uint256 totalRaised
    );

    event GoalReached(
        uint256 indexed campaignId,
        uint256 totalAmount,
        uint256 timestamp
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignCancelled(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 timestamp
    );

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            msg.sender == campaigns[_campaignId].creator,
            "Only campaign creator can call this function"
        );
        _;
    }

    constructor() {
        platformOwner = payable(msg.sender);
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(bytes(_title).length > 0, "Campaign title cannot be empty");
        require(bytes(_description).length > 0, "Campaign description cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than zero");
        require(_durationInDays > 0, "Campaign duration must be greater than zero");
        require(_durationInDays <= 365, "Campaign duration cannot exceed 365 days");

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        Campaign storage newCampaign = campaigns[campaignCounter];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.deadline = deadline;
        newCampaign.isActive = true;

        emit CampaignCreated(
            campaignCounter,
            msg.sender,
            _title,
            _goalAmount,
            deadline
        );

        campaignCounter++;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.isActive, "Campaign is not active");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than zero");
        require(!campaign.goalReached, "Campaign goal already reached");


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;

        emit ContributionMade(
            _campaignId,
            msg.sender,
            msg.value,
            campaign.raisedAmount
        );


        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
            emit GoalReached(_campaignId, campaign.raisedAmount, block.timestamp);
        }
    }

    function withdrawFunds(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.isActive, "Campaign is not active");
        require(
            campaign.goalReached || block.timestamp >= campaign.deadline,
            "Cannot withdraw: goal not reached and campaign still active"
        );
        require(campaign.raisedAmount > 0, "No funds to withdraw");

        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = 0;
        uint256 creatorAmount = totalAmount;


        if (campaign.goalReached) {
            platformFee = (totalAmount * platformFeePercentage) / 10000;
            creatorAmount = totalAmount - platformFee;
        }

        campaign.raisedAmount = 0;
        campaign.isActive = false;


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }
        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp >= campaign.deadline, "Campaign has not ended yet");
        require(!campaign.goalReached, "Cannot refund: campaign goal was reached");
        require(campaign.contributions[msg.sender] > 0, "No contribution found for refund");

        uint256 refundAmount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        campaign.raisedAmount -= refundAmount;

        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }

    function cancelCampaign(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.isActive, "Campaign is already inactive");
        require(!campaign.goalReached, "Cannot cancel: campaign goal already reached");

        campaign.isActive = false;

        emit CampaignCancelled(_campaignId, campaign.creator, block.timestamp);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getContributors(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (address[] memory)
    {
        return campaigns[_campaignId].contributors;
    }

    function setPlatformFee(uint256 _newFeePercentage)
        external
        onlyPlatformOwner
    {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }

    function transferOwnership(address payable _newOwner)
        external
        onlyPlatformOwner
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }
}
