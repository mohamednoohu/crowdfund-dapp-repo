// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract CrowdFund {

    enum ProjectStatus {WFA, RJC, APR, PGA, XR, XRA, XRR}

    struct Project {
        uint projectId; 
        uint minimumAmount;
        uint goal;  
        uint raisedAmount; 
        address owner;  
        //address charity; 
        string documentLink;
        ProjectStatus projectStatus; 
    }

    struct Charity {
        uint charityId;
        bool approved;
        string reason;
        string licenseDocsLink;
        address owner;  
    }

    struct Donor {
        uint donorId;
        address owner; 
        mapping(uint => uint) projectwiseContributions;
    }


    Project[] public projects;
    //mapping(address => Project) public projects;
    Charity[] public charities;
    //mapping(address => Charity) public charities;
    //Donor[] public donors;
    //mapping(address => Donor) public donors;
    address public boardAdmin;

    mapping (uint => Donor) donors;
    
    mapping (uint => Project[]) charityProjects; // Projects created under this charity

    mapping(uint => bool) approvedCharities; // Charities approved by the board

    string constant WFA = "Waiting for approval";
    string constant APR = "Approved";
    string constant RJC = "Rejected by charity";
    string constant PGA = "Project goal achieved";
    string constant XR = "Exchange requested";
    string constant XRA = "Exchange request approved";
    string constant XRR = "Exchange request rejected";

    
	ProjectStatus public projectStatus;
    mapping(ProjectStatus => string) public projectStatuses;

    modifier onlyBoardAdmin(){
		require(msg.sender==boardAdmin,"This operation can be performed only by Board admin");
		_;
	}
	
    constructor () {
        boardAdmin = msg.sender;
        projectStatuses[ProjectStatus.WFA] = WFA;
        projectStatuses[ProjectStatus.APR] = APR;
        projectStatuses[ProjectStatus.RJC] = RJC;
        projectStatuses[ProjectStatus.PGA] = PGA;
        projectStatuses[ProjectStatus.XR] = XR;
        projectStatuses[ProjectStatus.XRA] = XRA;
        projectStatuses[ProjectStatus.XRR] = XRR;
    }
    
    // Charity can change its project status only
   function changeProjectStatus(uint projectId, uint charityId, uint8 enumValue) public {
        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"This project was not created under your charity");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].projectId == projectId) {
                projectList[i].projectStatus = ProjectStatus(enumValue);
                break;
            }
        }
       
        //Project storage project = projects[index];
       // project.projectStatus = enumValue;
    }

    function createCharity(uint _charityId, string memory _licenseDocsLink, address charity) public onlyBoardAdmin {
        /*
        charities[msg.sender].charityId = charityId;
        charities[msg.sender].approved = false;
        charities[msg.sender].licenseDocsLink = licenseDocsLink;
        */
        
        Charity memory newCharity = Charity({
           charityId: _charityId,
           approved: true,
           reason: "",
           licenseDocsLink: _licenseDocsLink,
           owner: charity
        });

        charities.push(newCharity); 
        approvedCharities[_charityId] = true;
        
    }

    function approveCharity(uint index, uint charityId) public onlyBoardAdmin {
       // charities[charity].approved = true;
      //  charities[charity].reason = "";
        
        Charity storage charity = charities[index];
        charity.approved = true;
        approvedCharities[charityId] = true;
    }

    function rejectCharity(uint index, string memory reason) onlyBoardAdmin public {
        //charities[charity].approved = false;
       // charities[charity].reason = reason;
        Charity storage charity = charities[index];
        charity.approved = false;
        charity.reason = reason;

        //delete(approvedCharities[charity.charityId]);
    }

    // Charity will create the project once it got approved by the board
    function createProject(uint charityId, uint _projectId, uint _goal, address owner, string memory _documentLink) public {
        require(approvedCharities[charityId],"Charity is not yet approved");
    
        Project memory newProject = Project({
           projectId: _projectId,
           minimumAmount: 1000000,
           goal: _goal,
           raisedAmount: 0,
           owner: owner,
           //charity: msg.sender,
           documentLink: _documentLink,
           projectStatus: ProjectStatus.APR
        });

        projects.push(newProject);
        
        charityProjects[charityId].push(newProject);
        //charities[msg.sender].projects[_projectId].push(newProject);
        

        //charityProjects[msg.sender] = _projectId;
       
        /*
        projects[msg.sender].projectId = projectId;
        projects[msg.sender].requiredAmount = requiredAmount;
        projects[msg.sender].raisedAmount = raisedAmount;
        projects[msg.sender].documentLink = documentLink;
        projects[msg.sender].charity = charity;
        projects[msg.sender].projectStatus = PROJECTSTATUS.WFA;

        // Assign the projectId under this charity
        charities[charity].projects = projectId;
        */
    }
    /*
    function createDonor(uint _donorId) public {
        
        

        Donor storage newDonor = donors[donorIndex++];
           newDonor.donorId = _donorId;
           newDonor.owner = msg.sender;

    }
    */

    function getProjectFundDetails(uint charityId, uint projectId) public view returns (
        uint, uint, uint) {
            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                    if (projectList[i].goal == projectList[i].raisedAmount) {
                        //return (projectList[i].goal,projectList[i].raisedAmount,0);
                        revert("Project goal achieved");
                    } else {
                        return (
                            projectList[i].goal,
                            projectList[i].raisedAmount,
                            projectList[i].goal - projectList[i].raisedAmount
                        );
                    }
                }
            }

             revert("No such project exist under this charity");
    }

    function donate(uint charityId, uint projectId, uint donorId) public payable {
            bool status = false;
            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId && 
                    projectList[i].projectStatus == ProjectStatus.APR) {
                    if (projectList[i].goal == projectList[i].raisedAmount) {
                        revert("Project goal achieved");
                    } else {
                            require(msg.value > projectList[i].minimumAmount);
                            projectList[i].raisedAmount = projectList[i].raisedAmount + msg.value;

                            // Get the existing donor
                            Donor storage donor = donors[donorId];

                            // If the donor and message sender are same, the amount should be added with  
                            // existing amount under the specific project
                            if (donor.owner == msg.sender) {
                                donor.projectwiseContributions[projectId] += msg.value;
                            } else { // It means no donor already exist under this donorId
                                // Create a new donor
                                Donor storage newDonor = donors[donorId];
                                newDonor.donorId = donorId;
                                newDonor.owner = msg.sender;
                                newDonor.projectwiseContributions[projectId] = msg.value;
                            }

                            if (projectList[i].raisedAmount == projectList[i].goal) {
                                projectList[i].projectStatus = ProjectStatus.PGA;
                                status = true;
                            }
                    }
                }
            }

            if (!status)
                revert("No such project exist under this charity");
    }

/*
    function getRefund() public {
        require(block.number > deadline);
        require(raisedAmount < goal);
        require(contributions[msg.sender] > 0);
        
        
        msg.sender.transfer(contributions[msg.sender]);
        contributions[msg.sender] = 0;
       
    }
*/
    function getProjectStatus(uint charityId, uint projectId) external view returns (
        string memory) {
           Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                    return projectStatuses[projectList[i].projectStatus];
                } 
            }

            revert("No such project exist under this charity");
    }
}