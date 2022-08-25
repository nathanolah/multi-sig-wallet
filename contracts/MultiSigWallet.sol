// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
// send ether to: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 1000000000000000000, 0x00
// call TestContract callMe() function: 0x5FD6eB55D12E759a21C09eF703fe0CBa1DC9d88D, 0, 0xe73620c3000000000000000000000000000000000000000000000000000000000000007b

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance); 
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RevokeTransaction(address indexed owner, uint indexed txIndex);
    
    /* State Variables */
    address[] public owners;
    uint public numConfirmationsRequired;
    mapping(address => bool) public isOwner;

    /* 
        When a tranaction is submitted a new instance of transaction is created
        and pushed to the transactions array.
    */
    struct Transaction {
        address to; // the address the transaction is sent to
        uint value; // the amount of ether sent to the address
        bytes data; // the transaction data that can be use when transaction is sent to another contract
        bool executed; // if the transaction has executed
        uint numConfirmations; // 
    }

    Transaction[] public transactions;

    // for each transaction index we will have a mapping of key addresses with bool values
    // when an owner approves their address is stored in the mapping as true
    mapping(uint => mapping(address => bool)) isConfirmed; 

    /* Modifiers */
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction has already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Transaction is already confirmed");
        _;
    }

    modifier isExecuted(uint _txIndex) {
        require(transactions[_txIndex].executed, "Transaction has not executed");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0 && 
            _numConfirmationsRequired <= _owners.length, "Invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; ++i) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid address");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    fallback() external payable {}

    function deposit() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // an address will propose a transaction to the multi sig wallet
    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    // addresses of the multi sig wallet can confirm the proposed transaction
    function confirmTransaction(uint _txIndex) 
        public
        onlyOwner 
        txExists(_txIndex) 
        notExecuted(_txIndex) 
        notConfirmed(_txIndex) {
            //Transaction storage transaction = transactions[_txIndex];
            //transaction.numConfirmations += 1;
            //isConfirmed[_txIndex][msg.sender] = true;

            isConfirmed[_txIndex][msg.sender] = true;
            transactions[_txIndex].numConfirmations++;

            emit ConfirmTransaction(msg.sender, _txIndex);
    }

    // execute the transaction
    function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numConfirmations >= numConfirmationsRequired, 
            "Not enough confirmations to execute tx");
        transaction.executed = true;

        // Execute transaction
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");
        
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    // revoke the transaction 
    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) isExecuted(_txIndex) {
        require(isConfirmed[_txIndex][msg.sender], "Sender has not confirmed the transaction");
        isConfirmed[_txIndex][msg.sender] = false;
        transactions[_txIndex].numConfirmations--;

        emit RevokeTransaction(msg.sender, _txIndex);
    }

    /* Getters */
    function getOwners() public view returns(address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns(uint) {
        return transactions.length;
    }
    
    function getTransaction(uint _txIndex) public view returns(
        address to,
        uint value,
        bytes memory data,
        bool executed,
        uint numConfirmations
    ) {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }   
}

contract TestContract {
    uint public i;

    function callMe(uint j) public {
        i += j;
    }

    function getData() public pure returns (bytes memory) {
        return abi.encodeWithSignature("callMe(uint256)", 123);
    } 
}
