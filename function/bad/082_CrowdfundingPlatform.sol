
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
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount;
    address public owner;
    uint256 public platformFee = 25;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignCompleted(uint256 indexed campaignId);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createCampaignAndSetupRewards(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays,
        bool _enableAutoComplete,
        uint256 _minContribution,
        string memory _rewardTier1,
        string memory _rewardTier2
    ) public {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");

        uint256 campaignId = campaignCount;
        Campaign storage campaign = campaigns[campaignId];
        campaign.creator = msg.sender;
        campaign.title = _title;
        campaign.description = _description;
        campaign.goal = _goal;
        campaign.raised = 0;
        campaign.deadline = block.timestamp + (_durationInDays * 1 days);
        campaign.completed = false;
        campaign.withdrawn = false;

        campaignCount++;


        if (bytes(_rewardTier1).length > 0) {

        }


        if (_enableAutoComplete && _minContribution > 0) {

        }

        emit CampaignCreated(campaignId, msg.sender, _goal, campaign.deadline);
    }


    function calculatePlatformFee(uint256 _amount) public view returns (uint256) {
        return (_amount * platformFee) / 1000;
    }


    function contributeAndProcessRewards(uint256 _campaignId) public payable campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(!campaign.completed, "Campaign already completed");


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);


            if (campaign.contributors.length > 10) {


                if (msg.value >= 1 ether) {


                    if (campaign.raised + msg.value >= campaign.goal) {


                        if (campaign.contributors.length >= 50) {

                            campaign.raised += msg.value;
                            campaign.contributions[msg.sender] += msg.value;
                            campaign.completed = true;
                            emit CampaignCompleted(_campaignId);
                        } else {
                            campaign.raised += msg.value;
                            campaign.contributions[msg.sender] += msg.value;
                            campaign.completed = true;
                            emit CampaignCompleted(_campaignId);
                        }
                    } else {
                        campaign.raised += msg.value;
                        campaign.contributions[msg.sender] += msg.value;
                    }
                } else {
                    campaign.raised += msg.value;
                    campaign.contributions[msg.sender] += msg.value;
                }
            } else {
                campaign.raised += msg.value;
                campaign.contributions[msg.sender] += msg.value;
            }
        } else {
            campaign.raised += msg.value;
            campaign.contributions[msg.sender] += msg.value;


            if (campaign.raised >= campaign.goal) {
                campaign.completed = true;
                emit CampaignCompleted(_campaignId);
            }
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) public campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(campaign.completed, "Campaign not completed");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.raised >= campaign.goal, "Goal not reached");

        campaign.withdrawn = true;

        uint256 fee = calculatePlatformFee(campaign.raised);
        uint256 creatorAmount = campaign.raised - fee;

        payable(owner).transfer(fee);
        payable(campaign.creator).transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function refund(uint256 _campaignId) public campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline, "Campaign still active");
        require(!campaign.completed, "Campaign was successful");
        require(campaign.contributions[msg.sender] > 0, "No contribution found");

        uint256 amount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        campaign.raised -= amount;

        payable(msg.sender).transfer(amount);
    }


    function getCampaignInfo(uint256 _campaignId) public view campaignExists(_campaignId) returns (
        address,
        string memory,
        uint256,
        uint256,
        uint256,
        bool,
        uint256
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.contributors.length
        );
    }

    function getContribution(uint256 _campaignId, address _contributor) public view campaignExists(_campaignId) returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getContributors(uint256 _campaignId) public view campaignExists(_campaignId) returns (address[] memory) {
        return campaigns[_campaignId].contributors;
    }

    function updatePlatformFee(uint256 _newFee) public onlyOwner {
        require(_newFee <= 100, "Fee cannot exceed 10%");
        platformFee = _newFee;
    }
}
