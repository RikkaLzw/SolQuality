
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
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(address => uint256[]) public creatorCampaigns;

    uint256 public campaignCounter;
    uint256 public platformFee = 250;
    address public owner;


    event CampaignCreated(uint256 campaignId, address creator, uint256 goalAmount);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event CampaignEnded(uint256 campaignId, bool successful);


    error InvalidInput();
    error NotAllowed();
    error TransferFailed();

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {

        require(bytes(_title).length > 0);
        require(_goalAmount > 0);
        require(_durationInDays > 0 && _durationInDays <= 365);

        campaignCounter++;
        uint256 campaignId = campaignCounter;

        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: block.timestamp + (_durationInDays * 1 days),
            isActive: true,
            goalReached: false
        });

        creatorCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, msg.sender, _goalAmount);
        return campaignId;
    }

    function contribute(uint256 _campaignId) external payable {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.creator != address(0));
        require(campaign.isActive);
        require(block.timestamp < campaign.deadline);
        require(msg.value > 0);

        contributions[_campaignId][msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;


        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function endCampaign(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.creator == msg.sender);
        require(campaign.isActive);


        require(block.timestamp >= campaign.deadline || campaign.goalReached);

        campaign.isActive = false;

        if (campaign.goalReached) {
            uint256 platformFeeAmount = (campaign.raisedAmount * platformFee) / 10000;
            uint256 creatorAmount = campaign.raisedAmount - platformFeeAmount;

            (bool success1, ) = payable(campaign.creator).call{value: creatorAmount}("");
            if (!success1) revert TransferFailed();

            (bool success2, ) = payable(owner).call{value: platformFeeAmount}("");
            if (!success2) revert TransferFailed();
        }

        emit CampaignEnded(_campaignId, campaign.goalReached);
    }

    function withdrawContribution(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        uint256 contributedAmount = contributions[_campaignId][msg.sender];

        require(contributedAmount > 0);
        require(!campaign.isActive);
        require(!campaign.goalReached);

        contributions[_campaignId][msg.sender] = 0;
        campaign.raisedAmount -= contributedAmount;

        (bool success, ) = payable(msg.sender).call{value: contributedAmount}("");
        if (!success) revert TransferFailed();
    }

    function getCampaignDetails(uint256 _campaignId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        bool isActive,
        bool goalReached
    ) {
        Campaign memory campaign = campaigns[_campaignId];
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

    function getCreatorCampaigns(address _creator) external view returns (uint256[] memory) {
        return creatorCampaigns[_creator];
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }

    function setPlatformFee(uint256 _newFee) external {
        require(msg.sender == owner);
        require(_newFee <= 1000);


        platformFee = _newFee;
    }

    function emergencyWithdraw() external {
        require(msg.sender == owner);

        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner).call{value: balance}("");
            if (!success) revert TransferFailed();
        }
    }

    receive() external payable {

        if (msg.value > 0) revert NotAllowed();
    }
}
