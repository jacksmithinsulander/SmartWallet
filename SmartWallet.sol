// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

contract AuthorizedOwner {
    mapping(address => Balance) Balances;
    address authorizedCaller;

    struct Transaction {
        uint256 amount;
        uint256 timestamp;
        address sender;
    }

    struct Balance {
        uint256 total;
        uint256 depositIndex;
        uint256 withdrawalIndex;
        uint256 outgoingTranferalIndex;
        uint256 incomingTransferalIndex;
        mapping(uint256 => Transaction) deposits;
        mapping(uint256 => Transaction) withdrawals;
        mapping(uint256 => Transaction) outgoingTransfers;
        mapping(uint256 => Transaction) incomingTransfers;
    }

    modifier onlyCaller() {
        if (msg.sender != authorizedCaller) {
            revert("You are not authorized to call this function");
        }
        _;
    }

    modifier balanceChecked(uint256 _amount, address _sender) {
        require(_amount <= Balances[_sender].total, "Insufficient balance");
        _;
    }

    modifier contractChecked(uint256 _amount) {
        assert(_amount <= address(this).balance);
        _;
    }

    modifier isNotEmpty(string memory _action, uint256 _value) {
        string memory formattedString;
        formattedString = string(
            abi.encodePacked("Can not create an empty ", _action)
        );
        require(_value > 0, formattedString);
        _;
    }
}

contract ATMLogic is AuthorizedOwner {
    constructor(address caller) {
        authorizedCaller = caller;
    }

    function _balanceOf(address _sender, address _address)
        public
        view
        onlyCaller
        returns (uint256)
    {
        require(_sender == _address, "You can only check your own balance");
        return Balances[_address].total;
    }

    function _deposit(address _sender)
        external
        payable
        onlyCaller
        isNotEmpty("deposition", msg.value)
    {
        Balances[_sender].total += msg.value;

        Transaction memory deposition = Transaction(
            msg.value,
            block.timestamp,
            _sender
        );

        Balances[_sender].deposits[Balances[_sender].depositIndex] = deposition;
        Balances[_sender].depositIndex++;
    }

    function _withdraw(
        address _sender,
        address payable _to,
        uint256 _amount
    )
        external
        onlyCaller
        balanceChecked(_amount, _sender)
        contractChecked(_amount)
        isNotEmpty("withdrawal", _amount)
    {
        Balances[_sender].total -= _amount;

        Transaction memory withdrawal = Transaction(
            _amount,
            block.timestamp,
            _sender
        );

        Balances[_sender].withdrawals[
            Balances[_sender].withdrawalIndex
        ] = withdrawal;
        Balances[_sender].withdrawalIndex++;

        _to.transfer(_amount);
    }

    function _transfer(
        address _sender,
        address payable _to,
        uint256 _amount
    )
        external
        onlyCaller
        balanceChecked(_amount, _sender)
        contractChecked(_amount)
        isNotEmpty("transferal", _amount)
    {
        Balances[_sender].total -= _amount;
        Balances[_to].total += _amount;

        Transaction memory transferal = Transaction(
            _amount,
            block.timestamp,
            _sender
        );

        Balances[_sender].outgoingTransfers[
            Balances[_sender].outgoingTranferalIndex
        ] = transferal;
        Balances[_sender].outgoingTranferalIndex++;

        Balances[_to].incomingTransfers[
            Balances[_to].incomingTransferalIndex
        ] = transferal;
        Balances[_to].incomingTransferalIndex++;
    }
}

contract ATM {
    event LogError(string reason);
    event LogErrorCode(uint256 code);
    event LogErrorBytes(bytes data);
    event SuccessfullTransaction(
        bool success,
        string action,
        address sender,
        address recipient,
        uint256 amount
    );

    ATMLogic atm = new ATMLogic(address(this));

    function balanceOf(address _address) public returns (uint256) {
        uint256 balance;
        try atm._balanceOf(msg.sender, _address) returns (uint256 result) {
            balance = result;
        } catch Error(string memory reason) {
            emit LogError(reason);
        } catch (bytes memory data) {
            emit LogErrorBytes(data);
        }
        return balance;
    }

    function deposit() public payable returns (bool success) {
        try atm._deposit{value: msg.value}(msg.sender) {
            emit SuccessfullTransaction(
                true,
                "deposit",
                msg.sender,
                address(atm),
                msg.value
            );
            return true;
        } catch Error(string memory reason) {
            emit LogError(reason);
            return false;
        } catch (bytes memory data) {
            emit LogErrorBytes(data);
            return false;
        }
    }

    function withdraw(address payable _to, uint256 _amount)
        public
        returns (bool success)
    {
        try atm._withdraw(msg.sender, _to, _amount) {
            emit SuccessfullTransaction(
                true,
                "withdraw",
                msg.sender,
                _to,
                _amount
            );
            return true;
        } catch Error(string memory reason) {
            emit LogError(reason);
            return false;
        } catch Panic(uint256 code) {
            emit LogErrorCode(code);
            return false;
        } catch (bytes memory data) {
            emit LogErrorBytes(data);
            return false;
        }
    }

    function transfer(address payable _to, uint256 _amount)
        public
        returns (bool success)
    {
        try atm._transfer(msg.sender, _to, _amount) {
            emit SuccessfullTransaction(
                true,
                "transfer",
                msg.sender,
                _to,
                _amount
            );
            return true;
        } catch Error(string memory reason) {
            emit LogError(reason);
            return false;
        } catch Panic(uint256 code) {
            emit LogErrorCode(code);
            return false;
        } catch (bytes memory data) {
            emit LogErrorBytes(data);
            return false;
        }
    }
}
