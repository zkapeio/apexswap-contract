# @version >=0.3
"""
@title ApexSwap AMM DEX V1 Factory
@author zkape.io
"""

interface IERC165:
    def setApprovalForAll(_operator: address, _approved: bool): nonpayable

interface IERC721:
    def balanceOf(_owner: address) -> uint256: view
    def ownerOf(_tokenId: uint256) -> address: view

interface IERC1155:
    def balanceOf(_owner: address, _id: uint256) -> uint256: view
    def balanceOfBatch(_owners: DynArray[address, 255], _ids: DynArray[uint256, 255]) -> DynArray[uint256, 255]: view

interface ApexSwapV1Libray:
    def get_input_value(
        _delta_type: uint256,
        _pair: address,
        _number_items: uint256,
        _current_price: uint256,
        _delta_curve: uint256,
        _swap_fee: uint256) -> (uint256, uint256, uint256): view
    def get_output_value(
        _delta_type: uint256,
        _pair: address,
        _number_items: uint256,
        _current_price: uint256,
        _delta_curve: uint256,
        _swap_fee: uint256) -> (uint256, uint256, uint256): view

interface TKN:
    def mint(
        _owner: address,
        _nonce: uint256,
        _token0: address,
        _token1: address,
        _pool_id: uint256,
        _pool: address) -> uint256: nonpayable


event PairCreated:
    _pair_type: uint256
    _pair_length: uint256
    _token0: indexed(address)
    _token1: indexed(address)
    _pair: indexed(address)
    _delta_type: uint256
    _delta_curve: uint256
    _fee: uint256
    _token_ids: DynArray[uint256, MAX_SIZE]
    _amount_in: uint256
    _time: uint256

event SetNewPair:
    _controller: indexed(address)
    _old_pair: indexed(address)
    _new_pair: indexed(address)

event SetNewRouter:
    _controller: indexed(address)
    _old_router: indexed(address)
    _new_router: indexed(address)  

event SetNewLibrary:
    _controller: indexed(address)
    _old_library: indexed(address)
    _new_library: indexed(address)  

event SetNewTicket:
    _controller: indexed(address)
    _old_ticket: indexed(address)
    _new_ticket: indexed(address)  


struct PairKey:
    id: uint256
    token0: address
    token1: address
    pair: address
    delta_type: uint256 # delta method id: 0--linear delta, 1--exponential delta
    delta_curve: uint256
    fee: uint256
    price: uint256
    nft_ids: DynArray[uint256, MAX_SIZE]
    time: uint256

DELTA_TYPE: constant(uint256[3]) = [
    0, # linear delta
    1, # exponential delta
    2 # xyk delta
]

PAIR_TYPE: constant(uint256[3]) = [
    0, # trade
    1, # ETH/ERC20
    2  # NFT
]

MAX_SIZE: constant(uint256) = 50

ERC721_INTERFACE_ID: constant(bytes4[4]) = [
    0x01FFC9A7, 
    0x80AC58CD, 
    0x5B5E139F, 
    0x780E9D63
]

ERC1155_INTERFACE_ID: constant(bytes4[3]) = [
    0x01FFC9A7, 
    0xD9B67A26, 
    0x0E89341C
]

pair_eth_for_erc721: HashMap[address, HashMap[address, HashMap[uint256, address]]]
pair_erc20_for_erc721: HashMap[address, HashMap[address, address]]
pair_info: HashMap[uint256, PairKey]
pair_id: HashMap[address, uint256]

owner: public(address)
apex_pair: public(address)
apex_router: public(address)
apex_libray: public(address)
apex_ticket: public(address)

all_pairs: public(HashMap[uint256, address])
all_pair_length: public(uint256)
next_pair_length: public(uint256)
all_token_pair_length: public(HashMap[address, uint256])
pair_of_owner_to_index: HashMap[address, HashMap[address, uint256]]
pair_of_token_to_index: HashMap[address, HashMap[uint256, address]]

is_approved: HashMap[address, HashMap[address, bool]]


@external
def __init__(_pair: address, _library: address, _ticket: address):
    self.owner = msg.sender
    self.apex_pair = _pair
    self.apex_libray = _library
    self.apex_ticket = _ticket


@view
@external
def pair_of(_owner: address, _token0: address) -> uint256:
    return self.pair_of_owner_to_index[_owner][_token0]


@view
@external
def pair_of_owner_by_index(_owner: address, _token0: address, _index: uint256) -> address:
    return self.pair_eth_for_erc721[_owner][_token0][_index]


@view
@external
def pair_of_token_by_index(_token0: address, _index: uint256) -> address:
    return self.pair_of_token_to_index[_token0][_index]


@view
@external
def get_pair_dynamic_info(pair: address) -> (uint256, uint256, uint256, uint256):
    p_id: uint256 = self.pair_id[pair]
    pair_struct: PairKey = self.pair_info[p_id]
    delta_type: uint256 = pair_struct.delta_type
    delta: uint256 = pair_struct.delta_curve
    fee: uint256 = pair_struct.fee
    price: uint256 = pair_struct.price

    return delta_type, delta, fee, price


@internal
def _transfer_erc721(
    _token0: address, 
    _sender: address, 
    _spender: address, 
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> bool:
    
    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            raw_call(
                _token0,
                _abi_encode(_sender, _spender, _token_ids[i], method_id=method_id("transferFrom(address,address,uint256)"))
            )

    return True


@internal
def _transfer_erc1155(
    _token0: address, 
    _sender: address, 
    _spender: address, 
    _token_ids: DynArray[uint256, MAX_SIZE], 
    _amounts: DynArray[uint256, MAX_SIZE],
    _data: DynArray[Bytes[1024], MAX_SIZE]
) -> bool:
    assert len(_token_ids) == len(_amounts) and len(_amounts) == len(_data), "APEX:: OVERRUN"

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            raw_call(
                _token0,
                _abi_encode(
                    _sender, 
                    _spender, 
                    _token_ids[i], 
                    _amounts[i],
                    _data[i],
                    method_id=method_id("safeTransferFrom(address,address,uint256,uint256,bytes)"))
            )

    return True


@internal
def _transfer_erc20(
    _token1: address, 
    _sender: address, 
    _spender: address, 
    _amount_in: uint256
) -> bool:
    
    if not self.is_approved[self][_token1]:
        response: Bytes[32] = raw_call(
            _token1,
            _abi_encode(self, MAX_UINT256, method_id=method_id("approve(address,uint256)")),
            max_outsize=32
        )
        if len(response) != 0:
            assert convert(response, bool)
        self.is_approved[self][_token1] = True

    raw_call(
        _token1,
        _abi_encode(_sender, _spender, _amount_in, method_id=method_id("transferFrom(address,address,uint256)"))
    )

    return True


@internal
def _pair_setup(
    _ticket_id: uint256, 
    _pair_type: uint256, 
    _pair_address: address, 
    _token0: address, 
    _token1: address, 
    _trade: bool, 
    _is_nonfungible: bool
) -> bool:

    raw_call(
        _pair_address,
        _abi_encode(
            _ticket_id,
            _pair_type,
            self.apex_router,
            self,
            self.apex_ticket,
            _token0,
            _token1,
            _trade,
            _is_nonfungible,
            method_id=method_id("setup(uint256,uint256,address,address,address,address,address,bool,bool)")
        )
    )

    return True


@internal
def _write_pair_struct(
    _owner: address,
    _token0: address,
    _token1: address,
    _new_pair_address: address,
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _price: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> bool:

    pair_length: uint256 = self.all_pair_length

    new_pair_struct: PairKey = PairKey({
        id: pair_length,
        token0: _token0,
        token1: _token1,
        pair: _new_pair_address,
        delta_type: _delta_type,
        delta_curve: _delta_curve,
        fee: _fee,
        price: _price,
        nft_ids: _token_ids,
        time: block.timestamp
    })

    self.pair_info[pair_length] = new_pair_struct
    self.pair_id[_new_pair_address] = pair_length
    self.all_pairs[pair_length] = _new_pair_address
    self.all_pair_length += 1
    self.next_pair_length = self.all_pair_length + 1
    
    self.pair_eth_for_erc721[_owner][_token0][self.pair_of_owner_to_index[_owner][_token0]] = _new_pair_address
    self.pair_of_token_to_index[_token0][self.all_token_pair_length[_token0]] = _new_pair_address
    self.all_token_pair_length[_token0] += 1
    self.pair_of_owner_to_index[_owner][_token0] += 1

    return True


@internal
def _create_pair_erc721(
    _owner: address,
    _token0: address, 
    _token1: address,
    _price: uint256, 
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _amount_in: uint256
) -> (address, bool):

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            returnOwner: address = IERC721(_token0).ownerOf(_token_ids[i])
            assert returnOwner == _owner, "APEX:: FORK OWNER"

    new_pair_address: address = create_forwarder_to(self.apex_pair, value=_amount_in)
    assert new_pair_address != empty(address), "APEX:: UNVALID CREATE"

    transfer_successful: bool = self._transfer_erc721(_token0, _owner, new_pair_address, _token_ids)
    assert transfer_successful, "APEX:: UNVALID TRANSFER"

    writed: bool = self._write_pair_struct(
        _owner,
        _token0,
        _token1,
        new_pair_address,
        _delta_type,
        _delta_curve,
        _fee,
        _price,
        _token_ids
    )
    assert writed, "APEX:: UNVALID WRITE"

    return new_pair_address, True


@internal
def _create_pair_erc1155(
    _owner: address,
    _token0: address, 
    _token1: address,
    _price: uint256, 
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _amounts: DynArray[uint256, MAX_SIZE],
    _data: DynArray[Bytes[1024], MAX_SIZE],
    _amount_in: uint256
) -> (address, bool):

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            amount: uint256 = IERC1155(_token0).balanceOf(_owner, _token_ids[i])
            assert amount == _amounts[i], "APEX:: FORK OWNER"

    new_pair_address: address = create_forwarder_to(self.apex_pair, value=_amount_in)
    assert new_pair_address != empty(address), "APEX:: UNVALID CREATE"

    transfer_successful: bool = self._transfer_erc1155(_token0, _owner, new_pair_address, _token_ids, _amounts, _data)
    assert transfer_successful, "APEX:: UNVALID TRANSFER"

    writed: bool = self._write_pair_struct(
        _owner,
        _token0,
        _token1,
        new_pair_address,
        _delta_type,
        _delta_curve,
        _fee,
        _price,
        _token_ids
    )
    assert writed, "APEX:: UNVALID WRITE"

    return new_pair_address, True


@internal
def _check_exists(_pair_type: uint256, _token0: address, _price: uint256, _delta_type: uint256, _delta_curve: uint256, _number_items: uint256):
    assert _token0 != empty(address) and msg.sender != empty(address), "APEX:: UNVALID ADDRESS"
    assert _price != 0, "APEX:: ENTER UNVALID AMOUNT"
    assert _delta_type in DELTA_TYPE, "APEX:: UNVALID TYPE"
    assert _pair_type in PAIR_TYPE, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _delta_curve <= (_price * 90 / 100), "APEX:: UNVALID RISE CURVE"
    assert _number_items <= MAX_SIZE, "APEX:: EXCESS INPUT"


@internal
def _check_value(_pair: address, _pair_type: uint256, _price: uint256, _delta_type: uint256, _delta_curve: uint256, _fee: uint256, _number_items: uint256, _amount_in: uint256):
    new_current_price: uint256 = 0
    deposit_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, deposit_value, protocol_fee = ApexSwapV1Libray(self.apex_libray).get_input_value(_delta_type, _pair, _number_items, _price, _delta_curve, _fee)
    
    assert deposit_value == _amount_in, "APEX:: INSUFFICIENT BALANCE"


@payable
@external
def create_pair(
    _pair_type: uint256,
    _token0: address, 
    _token1: address,
    _price: uint256, 
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> address:

    """
    @dev Create an 'ERC721/ETH' pool
    """

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, _number_items)
    assert _number_items == len(_token_ids), "APEX:: UNVALID TOKEN LENGHT"
    assert _pair_type == 0, "APEX:: UNVALID PAIR TRADE TYPE"

    new_pair_address: address = empty(address)
    successful: bool = False

    new_pair_address, successful = self._create_pair_erc721(
        msg.sender,
        _token0,
        _token1,
        _price,
        _delta_type,
        _delta_curve,
        _fee,
        _token_ids,
        msg.value
    )
    assert successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    if _delta_type != 2:
        self._check_value(new_pair_address, _pair_type, _price, _delta_type, _delta_curve, _fee, _number_items, msg.value)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, True, True)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        _fee, 
        _token_ids,
        msg.value,
        block.timestamp)
    
    return new_pair_address


@payable
@external
def create_pair_eth(
    _pair_type: uint256,
    _token0: address,
    _token1: address,
    _price: uint256,
    _delta_type: uint256,
    _delta_curve: uint256,
    _number_items: uint256,
    _is_nonfungible: bool
) -> address:

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, _number_items)
    assert _pair_type == 1, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _token1 == empty(address), "APEX:: WRONG ETH PAIR"
    assert _delta_type != 2, "APEX:: WRONG TYPE"

    new_pair_address: address = create_forwarder_to(self.apex_pair, value=msg.value)
    assert new_pair_address != empty(address), "APEX:: UNVALID CREATE"

    writed: bool = self._write_pair_struct(
        msg.sender,
        _token0,
        _token1,
        new_pair_address,
        _delta_type,
        _delta_curve,
        0,
        _price,
        empty(DynArray[uint256, MAX_SIZE])
    )
    assert writed, "APEX:: UNVALID WRITE"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    self._check_value(new_pair_address, _pair_type, _price, _delta_type, _delta_curve, 0, _number_items, msg.value)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, False, _is_nonfungible)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        0, 
        empty(DynArray[uint256, MAX_SIZE]),
        msg.value,
        block.timestamp)
    
    return new_pair_address
        

@external
def create_pair_erc721(
    _pair_type: uint256,
    _token0: address,
    _token1: address,
    _price: uint256,
    _delta_type: uint256,
    _delta_curve: uint256,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> address:

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, _number_items)
    assert _number_items == len(_token_ids), "APEX:: UNVALID TOKEN ID"
    assert _pair_type == 2, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _delta_type != 2, "APEX:: WRONG TYPE"

    new_pair_address: address = empty(address)
    successful: bool = False

    new_pair_address, successful = self._create_pair_erc721(
        msg.sender,
        _token0,
        _token1,
        _price,
        _delta_type,
        _delta_curve,
        0,
        _token_ids,
        0
    )
    assert successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, False, True)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        0, 
        _token_ids,
        0,
        block.timestamp)

    return new_pair_address


@external
def create_pair_erc20_for_erc721(
    _pair_type: uint256,
    _token0: address,
    _token1: address,
    _price: uint256,
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _amount_in: uint256,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> address:

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, _number_items)
    assert _pair_type == 0, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _amount_in != 0, "APEX:: UNVALID AMOUNT"
    
    new_pair_address: address = empty(address)
    successful: bool = False
    new_pair_address, successful = self._create_pair_erc721(
        msg.sender,
        _token0,
        _token1,
        _price,
        _delta_type,
        _delta_curve,
        _fee,
        _token_ids,
        0
    )
    assert successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    transfer_erc20_successful: bool = self._transfer_erc20(_token1, msg.sender, new_pair_address, _amount_in)
    assert transfer_erc20_successful, "APEX:: UNVALID CALL"

    if _delta_type != 2:
        self._check_value(new_pair_address, _pair_type, _price, _delta_type, _delta_curve, _fee, _number_items, _amount_in)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, True, True)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        _fee, 
        _token_ids,
        _amount_in,
        block.timestamp)

    return new_pair_address


@external
def create_pair_erc20(
    _pair_type: uint256,
    _token0: address,
    _token1: address,
    _price: uint256,
    _delta_type: uint256,
    _delta_curve: uint256,
    _amount_in: uint256,
    _number_items: uint256
) -> address:

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, _number_items)
    assert _amount_in != 0, "APEX:: UNVALID ERC20 AMOUNT"
    assert _pair_type == 1, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _delta_type != 2, "APEX:: WRONG TYPE"

    new_pair_address: address = create_forwarder_to(self.apex_pair)
    assert new_pair_address != empty(address), "APEX:: UNVALID CREATE"

    writed: bool = self._write_pair_struct(
        msg.sender,
        _token0,
        _token1,
        new_pair_address,
        _delta_type,
        _delta_curve,
        0,
        _price,
        empty(DynArray[uint256, MAX_SIZE])
    )
    assert writed, "APEX:: UNVALID WRITE"

    transfer_erc20_successful: bool = self._transfer_erc20(_token1, msg.sender, new_pair_address, _amount_in)
    assert transfer_erc20_successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    self._check_value(new_pair_address, _pair_type, _price, _delta_type, _delta_curve, 0, _number_items, _amount_in)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, False, True)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        0, 
        empty(DynArray[uint256, MAX_SIZE]),
        _amount_in,
        block.timestamp)
    
    return new_pair_address


@payable
@external
def create_pair_fungible(
    _pair_type: uint256,
    _token0: address, 
    _token1: address,
    _price: uint256, 
    _delta_type: uint256,
    _delta_curve: uint256,
    _fee: uint256,
    _number_items: uint256,
    _amounts: DynArray[uint256, MAX_SIZE],
    _token_ids: DynArray[uint256, MAX_SIZE],
    _data: DynArray[Bytes[1024], MAX_SIZE]
) -> address:

    """
    @dev Create an 'ERC1155/ETH' pool
    """

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, len(_amounts))
    assert _pair_type == 0, "APEX:: UNVALID PAIR TRADE TYPE"

    new_pair_address: address = empty(address)
    successful: bool = False

    new_pair_address, successful = self._create_pair_erc1155(
        msg.sender,
        _token0,
        _token1,
        _price,
        _delta_type,
        _delta_curve,
        _fee,
        _token_ids,
        _amounts,
        _data,
        msg.value
    )
    assert successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    if _delta_type != 2:
        self._check_value(new_pair_address, _pair_type, _price, _delta_type, _delta_curve, _fee, _number_items, msg.value)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, True, False)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        _fee, 
        _token_ids,
        msg.value,
        block.timestamp)
    
    return new_pair_address


@external
def create_pair_pure_fungible(
    _pair_type: uint256,
    _token0: address,
    _token1: address,
    _price: uint256,
    _delta_type: uint256,
    _delta_curve: uint256,
    _number_items: uint256,
    _amounts: DynArray[uint256, MAX_SIZE],
    _token_ids: DynArray[uint256, MAX_SIZE],
    _data: DynArray[Bytes[1024], MAX_SIZE]
) -> address:

    self._check_exists(_pair_type, _token0, _price, _delta_type, _delta_curve, len(_amounts))
    assert _pair_type == 2, "APEX:: UNVALID PAIR TRADE TYPE"
    assert _delta_type != 2, "APEX:: WRONG TYPE"

    new_pair_address: address = empty(address)
    successful: bool = False

    new_pair_address, successful = self._create_pair_erc1155(
        msg.sender,
        _token0,
        _token1,
        _price,
        _delta_type,
        _delta_curve,
        0,
        _token_ids,
        _amounts,
        _data,
        0
    )
    assert successful, "APEX:: UNVALID CALL"

    nonce: uint256 = _price * block.timestamp
    ti: uint256 = TKN(self.apex_ticket).mint(msg.sender, nonce, _token0, _token1, self.all_pair_length, new_pair_address)

    setup_successful: bool = self._pair_setup(ti, _pair_type, new_pair_address, _token0, _token1, False, False)
    assert setup_successful, "APEX:: UNVALID CALL"

    log PairCreated(
        _pair_type,
        self.all_pair_length, 
        _token0, 
        _token1, 
        new_pair_address, 
        _delta_type, 
        _delta_curve, 
        0, 
        _token_ids,
        0,
        block.timestamp)

    return new_pair_address


@external
def set_new_pair(_new_pair: address):
    """
    @dev update new 'pair' address
    @param _new_pair new 'pair' address
    """
    assert self.owner == msg.sender, "APEX:: ONLY OWNER"

    old_pair: address = self.apex_pair
    self.apex_pair = _new_pair
    log SetNewPair(msg.sender, old_pair, _new_pair)


@external
def set_new_router(_new_router: address):
    """
    @dev update new 'router' address
    @param _new_router new 'router' address
    """
    assert self.owner == msg.sender, "APEX:: ONLY OWNER"

    old_router: address = self.apex_router
    self.apex_router = _new_router
    log SetNewRouter(msg.sender, old_router, _new_router)


@external
def set_new_library(_new_library: address):
    """
    @dev update new 'library' address
    @param _new_library new 'library' address
    """
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    old_library: address = self.apex_libray
    self.apex_libray = _new_library
    log SetNewLibrary(msg.sender, old_library, _new_library)


@external
def set_new_ticket(_new_ticket: address):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    old_ticket: address = self.apex_ticket
    self.apex_ticket = _new_ticket
    log SetNewTicket(msg.sender, old_ticket, _new_ticket)


@view
@external
def get_balance(_b: address) -> uint256:
    return _b.balance