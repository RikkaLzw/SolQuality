
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeePercent = 5;
    address public platformOwner;

    event CampaignCreated(uint256 campaignId, address creator, uint256 targetAmount);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);

    constructor() {
        platformOwner = msg.sender;
    }




    function createCampaignAndSetupDetails(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays,
        bool _autoActivate,
        uint256 _minimumContribution,
        string memory _category
    ) public {

        if (_targetAmount > 0) {
            if (bytes(_title).length > 0) {
                if (bytes(_description).length > 0) {
                    if (_durationInDays > 0 && _durationInDays <= 365) {
                        campaignCounter++;
                        Campaign storage newCampaign = campaigns[campaignCounter];
                        newCampaign.creator = payable(msg.sender);
                        newCampaign.title = _title;
                        newCampaign.description = _description;
                        newCampaign.targetAmount = _targetAmount;
                        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);

                        if (_autoActivate) {
                            if (_minimumContribution > 0) {
                                newCampaign.isActive = true;

                                if (bytes(_category).length > 0) {

                                }
                            } else {
                                newCampaign.isActive = false;
                            }
                        } else {
                            newCampaign.isActive = false;
                        }

                        emit CampaignCreated(campaignCounter, msg.sender, _targetAmount);
                    }
                }
            }
        }
    }


    function validateCampaignExists(uint256 _campaignId) public view returns (bool) {
        return _campaignId > 0 && _campaignId <= campaignCounter;
    }



    function contributeAndUpdateStats(uint256 _campaignId) public payable {
        if (validateCampaignExists(_campaignId)) {
            Campaign storage campaign = campaigns[_campaignId];
            if (campaign.isActive) {
                if (block.timestamp < campaign.deadline) {
                    if (msg.value > 0) {
                        if (campaign.contributions[msg.sender] == 0) {
                            campaign.contributors.push(msg.sender);

                            if (campaign.contributors.length > 10) {

                                if (campaign.raisedAmount > campaign.targetAmount / 2) {

                                }
                            }
                        }

                        campaign.contributions[msg.sender] += msg.value;
                        campaign.raisedAmount += msg.value;

                        emit ContributionMade(_campaignId, msg.sender, msg.value);


                        if (campaign.raisedAmount >= campaign.targetAmount) {

                        }
                    }
                }
            }
        }
    }



    function getDetailedCampaignInfo(
        uint256 _campaignId,
        bool _includeContributors,
        bool _includeFinancials,
        uint256 _contributorOffset,
        uint256 _contributorLimit,
        bool _calculatePercentages
    ) public view returns (
        string memory,
        uint256,
        uint256,
        address[] memory,
        uint256[] memory
    ) {
        Campaign storage campaign = campaigns[_campaignId];

        address[] memory contributorsList;
        uint256[] memory contributionAmounts;

        if (_includeContributors && campaign.contributors.length > 0) {
            uint256 startIndex = _contributorOffset;
            uint256 endIndex = startIndex + _contributorLimit;
            if (endIndex > campaign.contributors.length) {
                endIndex = campaign.contributors.length;
            }

            contributorsList = new address[](endIndex - startIndex);
            contributionAmounts = new uint256[](endIndex - startIndex);

            for (uint256 i = startIndex; i < endIndex; i++) {
                contributorsList[i - startIndex] = campaign.contributors[i];
                if (_calculatePercentages) {
                    contributionAmounts[i - startIndex] = (campaign.contributions[campaign.contributors[i]] * 100) / campaign.raisedAmount;
                } else {
                    contributionAmounts[i - startIndex] = campaign.contributions[campaign.contributors[i]];
                }
            }
        }

        return (
            campaign.title,
            _includeFinancials ? campaign.targetAmount : 0,
            _includeFinancials ? campaign.raisedAmount : 0,
            contributorsList,
            contributionAmounts
        );
    }

    function withdrawFunds(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(campaign.raisedAmount >= campaign.targetAmount, "Target not reached");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        require(block.timestamp >= campaign.deadline, "Campaign still active");

        campaign.fundsWithdrawn = true;
        uint256 platformFee = (campaign.raisedAmount * platformFeePercent) / 100;
        uint256 creatorAmount = campaign.raisedAmount - platformFee;

        payable(platformOwner).transfer(platformFee);
        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function refund(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raisedAmount < campaign.targetAmount, "Campaign was successful");
        require(campaign.contributions[msg.sender] > 0, "No contribution found");

        uint256 refundAmount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;

        payable(msg.sender).transfer(refundAmount);
    }


    function calculatePlatformFee(uint256 _amount) public view returns (uint256) {
        return (_amount * platformFeePercent) / 100;
    }

    function activateCampaign(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can activate");
        require(!campaign.isActive, "Already active");
        require(block.timestamp < campaign.deadline, "Campaign expired");

        campaign.isActive = true;
    }

    function getCampaignBasicInfo(uint256 _campaignId) public view returns (
        address,
        string memory,
        uint256,
        uint256,
        uint256,
        bool
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive
        );
    }

    function getContributorCount(uint256 _campaignId) public view returns (uint256) {
        return campaigns[_campaignId].contributors.length;
    }

    function getContribution(uint256 _campaignId, address _contributor) public view returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }
}
