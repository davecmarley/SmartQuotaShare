//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

//this contract is set up to create one year sidecar contracts.

contract SmartQuotaShare {

    uint256 constant ONE_YEAR_IN_SECONDS = uint256(365 days);
    using SafeCast for uint256;

    struct Cedent {
        string name;
        address cedentAddress;
    }

    struct Reinsurer {
        string name;
        address reinsurerAddress;
    }

    struct QuotaShareAgreement {
        string name;
        Cedent cedent;
        Reinsurer reinsurer;
        uint8 quotaShare;
        bool commuted;
        uint balanceSettlementAccount;
        uint balanceCollateralAccount;
        uint effectiveTime;
        uint terminationDate;
        bool cedentCommutationSigned;
        bool reinsurerCommutationSigned;
    }

    Cedent[] public listCedents;

    Reinsurer[] public listReinsurers;

    QuotaShareAgreement[] public listQuotaShareAgreements;

    function createQuotaShareAgreement (
        string memory _name, 
        string memory _cedentName, address _cedentAddress,
        string memory _reinsurerName, address _reinsurerAddress,
        uint8 _quotaShare
        ) public {
        
        Cedent memory newCedent;
        newCedent.name = _cedentName;
        newCedent.cedentAddress = _cedentAddress;

        Reinsurer memory newReinsurer;
        newReinsurer.name = _reinsurerName;
        newReinsurer.reinsurerAddress = _reinsurerAddress;
        
        QuotaShareAgreement memory newQuotaShareAgreement;
        
        newQuotaShareAgreement.name = _name;
        newQuotaShareAgreement.cedent = newCedent;
        newQuotaShareAgreement.reinsurer = newReinsurer;
        newQuotaShareAgreement.quotaShare = _quotaShare;
        newQuotaShareAgreement.effectiveTime = block.timestamp;
        newQuotaShareAgreement.terminationDate = block.timestamp + ONE_YEAR_IN_SECONDS;
               
        listQuotaShareAgreements.push(newQuotaShareAgreement);
    }

function collateralizeQuotaShare(
    uint indexQuotaShareAgreement
    ) public payable {

        require(indexQuotaShareAgreement < listQuotaShareAgreements.length, "Error, invalid agreement index");

        QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];

        listQuotaShareAgreements[indexQuotaShareAgreement].balanceCollateralAccount += msg.value;

        require(quotaShareAgreement.reinsurer.reinsurerAddress == msg.sender, "Error, not reinsurer");
    }

    function creditSettlementAccount (
        uint indexQuotaShareAgreement
        ) public payable {

            require(indexQuotaShareAgreement < listQuotaShareAgreements.length, "Error, invalid agreement index");

            QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];

            quotaShareAgreement.balanceSettlementAccount += msg.value;
        
            require(quotaShareAgreement.cedent.cedentAddress == msg.sender, "Error, not cedent");
        }

    function debitSettlementAccount (
        uint indexQuotaShareAgreement,
        uint debitAmount
        ) public  {

            require(indexQuotaShareAgreement < listQuotaShareAgreements.length, "Error, invalid agreement index");

            QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];

            if (quotaShareAgreement.balanceSettlementAccount >= debitAmount){
                quotaShareAgreement.balanceSettlementAccount -= debitAmount;
            } else {
                uint debitToCollateralAccount = debitAmount - quotaShareAgreement.balanceSettlementAccount;
                quotaShareAgreement.balanceSettlementAccount = 0;
                quotaShareAgreement.balanceCollateralAccount -= debitToCollateralAccount;
            }
    
            require(quotaShareAgreement.cedent.cedentAddress == msg.sender, "Error, not cedent");
        }

    function setCedentCommutationSigned (
        uint indexQuotaShareAgreement
        ) public {
            require(indexQuotaShareAgreement < listQuotaShareAgreements.length, "Error, invalid agreement index");

            QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];

            quotaShareAgreement.cedentCommutationSigned = true;

            if (quotaShareAgreement.reinsurerCommutationSigned == true){
                commuteQuotaShareAgreement(indexQuotaShareAgreement);
            }
            
            require(quotaShareAgreement.cedent.cedentAddress == msg.sender, "Error, not cedent");
    }

    function setReinsurerCommutationSigned (
        uint indexQuotaShareAgreement
        ) public {
            require(indexQuotaShareAgreement < listQuotaShareAgreements.length, "Error, invalid agreement index");

            QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];

            quotaShareAgreement.reinsurerCommutationSigned = true;

            if (quotaShareAgreement.cedentCommutationSigned == true){
                commuteQuotaShareAgreement(indexQuotaShareAgreement);
            }
            
            require(quotaShareAgreement.reinsurer.reinsurerAddress == msg.sender, "Error, not reinsurer");
    }

    function commuteQuotaShareAgreement (
        uint indexQuotaShareAgreement
        ) public {
            
            QuotaShareAgreement storage quotaShareAgreement = listQuotaShareAgreements[indexQuotaShareAgreement];
            
            address payable to = payable (quotaShareAgreement.reinsurer.reinsurerAddress);
            to.transfer(quotaShareAgreement.balanceSettlementAccount + quotaShareAgreement.balanceCollateralAccount);
        
            quotaShareAgreement.balanceSettlementAccount = 0;
            quotaShareAgreement.balanceCollateralAccount = 0;

            quotaShareAgreement.commuted = true;

        //need to add if statements to these requires so that they're not required if termination
        //date is passed.
        require(quotaShareAgreement.cedentCommutationSigned == true);
        require(quotaShareAgreement.reinsurerCommutationSigned == true);
        }


}
