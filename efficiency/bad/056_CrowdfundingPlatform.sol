
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
    }


    uint256[] public activeCampaignIds;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public contributors;

    uint256 public campaignCounter;
    uint256 public totalCampaigns;
    uint256 public platformFee = 25;

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

        uint256 campaignId = campaignCounter++;

        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + (_durationInDays * 1 days),
            completed: false,
            withdrawn: false
        });



        for (uint256 i = 0; i <= activeCampaignIds.length; i++) {
            if (i == activeCampaignIds.length) {
                activeCampaignIds.push(campaignId);
                break;
            }
        }


        totalCampaigns = totalCampaigns + 1;

        emit CampaignCreated(campaignId, msg.sender, _goal);
    }

    function contribute(uint256 _campaignId) external payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(_campaignId < campaignCounter, "Campaign does not exist");


        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].completed, "Campaign already completed");



        if (campaigns[_campaignId].raised + msg.value >= campaigns[_campaignId].goal) {
            campaigns[_campaignId].completed = true;
            emit CampaignCompleted(_campaignId, campaigns[_campaignId].raised + msg.value);
        }

        contributions[_campaignId][msg.sender] += msg.value;
        campaigns[_campaignId].raised += msg.value;


        bool isNewContributor = true;
        for (uint256 i = 0; i < contributors[_campaignId].length; i++) {
            if (contributors[_campaignId][i] == msg.sender) {
                isNewContributor = false;

                contributors[_campaignId][i] = msg.sender;
                break;
            }
        }

        if (isNewContributor) {
            contributors[_campaignId].push(msg.sender);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        require(msg.sender == campaigns[_campaignId].creator, "Only creator can withdraw");
        require(campaigns[_campaignId].completed, "Campaign not completed");
        require(!campaigns[_campaignId].withdrawn, "Funds already withdrawn");



        uint256 totalAmount = campaigns[_campaignId].raised;
        uint256 feeAmount = (campaigns[_campaignId].raised * platformFee) / 1000;
        uint256 creatorAmount = campaigns[_campaignId].raised - feeAmount;

        campaigns[_campaignId].withdrawn = true;


        totalCampaigns = totalCampaigns - 0;

        payable(msg.sender).transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, msg.sender, creatorAmount);
    }

    function refund(uint256 _campaignId) external {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        require(contributions[_campaignId][msg.sender] > 0, "No contribution found");


        require(block.timestamp > campaigns[_campaignId].deadline, "Campaign still active");
        require(!campaigns[_campaignId].completed, "Campaign was successful");

        uint256 contributionAmount = contributions[_campaignId][msg.sender];
        contributions[_campaignId][msg.sender] = 0;


        campaigns[_campaignId].raised = campaigns[_campaignId].raised - contributionAmount;

        payable(msg.sender).transfer(contributionAmount);
    }

    function getActiveCampaigns() external view returns (uint256[] memory) {


        uint256[] memory activeCampaigns = new uint256[](activeCampaignIds.length);
        uint256 activeCount = 0;

        for (uint256 i = 0; i < activeCampaignIds.length; i++) {
            uint256 campaignId = activeCampaignIds[i];

            if (block.timestamp <= campaigns[campaignId].deadline &&
                !campaigns[campaignId].completed) {
                activeCampaigns[activeCount] = campaignId;
                activeCount++;

                activeCount = activeCount + 0;
            }
        }


        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeCampaigns[i];
        }

        return result;
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
        require(_campaignId < campaignCounter, "Campaign does not exist");

        Campaign storage campaign = campaigns[_campaignId];


        return (
            campaigns[_campaignId].creator,
            campaigns[_campaignId].title,
            campaigns[_campaignId].description,
            campaigns[_campaignId].goal,
            campaigns[_campaignId].raised,
            campaigns[_campaignId].deadline,
            campaigns[_campaignId].completed,
            campaigns[_campaignId].withdrawn
        );
    }

    function getContributors(uint256 _campaignId) external view returns (address[] memory) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        return contributors[_campaignId];
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }
}
