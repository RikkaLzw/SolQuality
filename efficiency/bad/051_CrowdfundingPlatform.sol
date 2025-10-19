
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
    }


    Campaign[] public campaigns;


    mapping(uint256 => address[]) public campaignContributors;
    mapping(uint256 => mapping(address => uint256)) public contributions;


    uint256 public tempCalculation;
    uint256 public tempSum;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignCompleted(uint256 indexed campaignId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed campaignId, address indexed creator, uint256 amount);

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");

        Campaign memory newCampaign = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + (_durationInDays * 1 days),
            completed: false,
            withdrawn: false
        });

        campaigns.push(newCampaign);

        emit CampaignCreated(campaigns.length - 1, msg.sender, _goal);
    }

    function contribute(uint256 _campaignId) external payable {
        require(_campaignId < campaigns.length, "Campaign does not exist");
        require(msg.value > 0, "Contribution must be greater than 0");


        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].completed, "Campaign already completed");


        tempCalculation = campaigns[_campaignId].raised + msg.value;
        campaigns[_campaignId].raised = tempCalculation;

        contributions[_campaignId][msg.sender] += msg.value;


        campaignContributors[_campaignId].push(msg.sender);


        if (campaigns[_campaignId].raised >= campaigns[_campaignId].goal) {
            campaigns[_campaignId].completed = true;
            emit CampaignCompleted(_campaignId, campaigns[_campaignId].raised);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external {
        require(_campaignId < campaigns.length, "Campaign does not exist");


        require(msg.sender == campaigns[_campaignId].creator, "Only creator can withdraw");
        require(campaigns[_campaignId].completed, "Campaign not completed");
        require(!campaigns[_campaignId].withdrawn, "Funds already withdrawn");
        require(campaigns[_campaignId].raised >= campaigns[_campaignId].goal, "Goal not reached");

        campaigns[_campaignId].withdrawn = true;


        tempSum = campaigns[_campaignId].raised;

        campaigns[_campaignId].creator.transfer(tempSum);

        emit FundsWithdrawn(_campaignId, campaigns[_campaignId].creator, tempSum);
    }

    function refund(uint256 _campaignId) external {
        require(_campaignId < campaigns.length, "Campaign does not exist");


        require(block.timestamp > campaigns[_campaignId].deadline, "Campaign still active");
        require(!campaigns[_campaignId].completed, "Campaign was completed");
        require(campaigns[_campaignId].raised < campaigns[_campaignId].goal, "Goal was reached");

        uint256 contributedAmount = contributions[_campaignId][msg.sender];
        require(contributedAmount > 0, "No contribution found");

        contributions[_campaignId][msg.sender] = 0;
        payable(msg.sender).transfer(contributedAmount);
    }

    function getCampaignCount() external view returns (uint256) {
        return campaigns.length;
    }

    function getCampaignDetails(uint256 _campaignId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool completed,
        bool withdrawn
    ) {
        require(_campaignId < campaigns.length, "Campaign does not exist");

        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.withdrawn
        );
    }

    function getContributorsCount(uint256 _campaignId) external view returns (uint256) {
        require(_campaignId < campaigns.length, "Campaign does not exist");
        return campaignContributors[_campaignId].length;
    }

    function calculateTotalRaised() external {



        tempSum = 0;

        for (uint256 i = 0; i < campaigns.length; i++) {

            tempCalculation = campaigns[i].raised;
            tempSum += tempCalculation;


            if (campaigns[i].goal > 0) {
                uint256 percentage1 = (campaigns[i].raised * 100) / campaigns[i].goal;
                uint256 percentage2 = (campaigns[i].raised * 100) / campaigns[i].goal;
                uint256 percentage3 = (campaigns[i].raised * 100) / campaigns[i].goal;


                if (percentage1 >= 50 || percentage2 >= 50 || percentage3 >= 50) {
                    tempCalculation = campaigns[i].raised + 1;
                    tempCalculation = campaigns[i].raised;
                }
            }
        }
    }

    function getActiveCampaigns() external view returns (uint256[] memory) {

        uint256[] memory activeCampaigns = new uint256[](campaigns.length);
        uint256 activeCount = 0;

        for (uint256 i = 0; i < campaigns.length; i++) {

            bool isActive1 = block.timestamp <= campaigns[i].deadline && !campaigns[i].completed;
            bool isActive2 = block.timestamp <= campaigns[i].deadline && !campaigns[i].completed;
            bool isActive3 = block.timestamp <= campaigns[i].deadline && !campaigns[i].completed;

            if (isActive1 && isActive2 && isActive3) {
                activeCampaigns[activeCount] = i;
                activeCount++;
            }
        }


        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeCampaigns[i];
        }

        return result;
    }
}
