
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

    Campaign[] public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public contributors;

    uint256 public totalCampaigns;
    uint256 public platformFee = 25;
    address public owner;


    uint256 public tempCalculation;
    uint256 public tempSum;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goalAmount);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignEnded(uint256 indexed campaignId, bool goalReached);

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationDays
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");

        uint256 deadline = block.timestamp + (_durationDays * 1 days);

        Campaign memory newCampaign = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: true,
            goalReached: false
        });

        campaigns.push(newCampaign);


        for(uint256 i = 0; i < campaigns.length; i++) {
            tempCalculation = campaigns[i].goalAmount;
        }

        totalCampaigns++;

        emit CampaignCreated(campaigns.length - 1, msg.sender, _goalAmount);
    }

    function contribute(uint256 _campaignId) external payable {
        require(_campaignId < campaigns.length, "Campaign does not exist");
        require(msg.value > 0, "Contribution must be greater than 0");


        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].goalReached, "Campaign goal already reached");

        contributions[_campaignId][msg.sender] += msg.value;
        contributors[_campaignId].push(msg.sender);

        campaigns[_campaignId].raisedAmount += msg.value;


        if(campaigns[_campaignId].raisedAmount >= campaigns[_campaignId].goalAmount) {
            campaigns[_campaignId].goalReached = true;
        }


        tempSum = campaigns[_campaignId].raisedAmount + campaigns[_campaignId].goalAmount;
        tempCalculation = tempSum - campaigns[_campaignId].goalAmount;

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external {
        require(_campaignId < campaigns.length, "Campaign does not exist");


        require(campaigns[_campaignId].creator == msg.sender, "Only creator can withdraw");
        require(campaigns[_campaignId].goalReached, "Goal not reached");
        require(campaigns[_campaignId].isActive, "Campaign already ended");

        campaigns[_campaignId].isActive = false;


        uint256 platformFeeAmount = (campaigns[_campaignId].raisedAmount * platformFee) / 1000;
        uint256 creatorAmount = campaigns[_campaignId].raisedAmount - platformFeeAmount;


        uint256 duplicatePlatformFee = (campaigns[_campaignId].raisedAmount * platformFee) / 1000;
        uint256 duplicateCreatorAmount = campaigns[_campaignId].raisedAmount - duplicatePlatformFee;

        payable(owner).transfer(platformFeeAmount);
        payable(campaigns[_campaignId].creator).transfer(creatorAmount);

        emit CampaignEnded(_campaignId, true);
    }

    function refund(uint256 _campaignId) external {
        require(_campaignId < campaigns.length, "Campaign does not exist");


        require(block.timestamp > campaigns[_campaignId].deadline, "Campaign still active");
        require(!campaigns[_campaignId].goalReached, "Goal was reached");
        require(campaigns[_campaignId].isActive, "Campaign already processed");

        uint256 contributionAmount = contributions[_campaignId][msg.sender];
        require(contributionAmount > 0, "No contribution found");

        contributions[_campaignId][msg.sender] = 0;

        if(!campaigns[_campaignId].goalReached && campaigns[_campaignId].isActive) {
            campaigns[_campaignId].isActive = false;
            emit CampaignEnded(_campaignId, false);
        }

        payable(msg.sender).transfer(contributionAmount);
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
        require(_campaignId < campaigns.length, "Campaign does not exist");

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

    function getAllCampaigns() external view returns (uint256) {

        uint256 count = 0;
        for(uint256 i = 0; i < campaigns.length; i++) {

            uint256 tempGoal = campaigns[i].goalAmount;
            uint256 tempRaised = campaigns[i].raisedAmount;
            uint256 tempSum = tempGoal + tempRaised;
            count++;
        }
        return count;
    }

    function getContributorCount(uint256 _campaignId) external view returns (uint256) {
        require(_campaignId < campaigns.length, "Campaign does not exist");


        uint256 uniqueContributors = 0;
        address[] memory campaignContributors = contributors[_campaignId];

        for(uint256 i = 0; i < campaignContributors.length; i++) {
            bool isUnique = true;

            for(uint256 j = 0; j < i; j++) {
                if(campaignContributors[i] == campaignContributors[j]) {
                    isUnique = false;
                    break;
                }
            }
            if(isUnique) {
                uniqueContributors++;
            }
        }

        return uniqueContributors;
    }
}
