pragma solidity ^0.4.0;

contract IToken {
  function balanceOf(address _address) constant returns (uint balance);
  function transfer(address _to, uint _value) returns (bool success);
}

contract BKXToken is IToken {
	string public standard = 'BKXToken 0.1';
    string public name = 'BKXToken';
    string public symbol = 'BKX';
	  
	address owner;

	modifier owneronly { if (msg.sender == owner) _; }

	function setOwner(address _owner) owneronly {
	    owner = _owner;
	}
	
    mapping (address => uint256) public balanceFor;
	
    function BKXToken() {
	    owner = msg.sender;
        balanceFor[msg.sender] = 3000000;              // Give the creator all initial tokens
    }
    
    function balanceOf(address _address) constant returns (uint balance) {
        return balanceFor[_address];
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balanceFor[tx.origin] < _value) throw;           // Check if the sender has enough
        if (balanceFor[_to] + _value < balanceFor[_to]) throw; // Check for overflows
        balanceFor[tx.origin] -= _value;                     // Subtract from the sender
        balanceFor[_to] += _value;                            // Add the same to the recipient
        return true;
    }
	
	function kill() owneronly {
		suicide(msg.sender);
	}
}