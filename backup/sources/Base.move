module coin_flip::Base {
    // Part 1: imports
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    // Use this dependency to get a type wrapper for UTF-8 strings
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use std::vector;
    use sui::event;

    /// User doesn't have enough coins to play a round on the suizino
    const ENotEnoughMoney: u64 = 1;
    const EOutOfService: u64 = 2;

    /// head or tail 2
    const AmountOfCombinations: u8 = 2;


    struct CoinFlip has key, store{
        id: UID,
        name: String,
        description: String,
        cost_per_game: u64,
        coinflip_balance: Balance<SUI>
    }

    struct CoinFlipOwnership has key, store{
        id: UID
    }

    struct GambleEvent has copy, drop{
        id: ID,
        winnings: u64,
        gambler: address,
        slot_1: u8,
    }

    // initialize our Suizino
    fun init(ctx: &mut TxContext) {
        let admin = @0xf52c7a83d88ad4a0a5e190289c6f86cc0c6f2403;

        transfer::transfer(CoinFlipOwnership{id: object::new(ctx)}, admin);

        transfer::share_object(CoinFlip {
            id: object::new(ctx),
            name: string::utf8(b"Suicflip"),
            description: string::utf8(b"A small unsafe Suicflip."),
            cost_per_game: 100,
            coinflip_balance: balance::zero()
        });

    }

    public fun cost_per_game(self: &CoinFlip): u64 {
        self.cost_per_game
    }

    public fun coinflip_balance(self:  &CoinFlip): u64{
       balance::value<SUI>(&self.coinflip_balance)
    }

    // let's play a game
    public entry fun gamble(coinflip: &mut CoinFlip, wallet: &mut Coin<SUI>, amount: u64, player_choice: u8, ctx: &mut TxContext){

        coinflip.cost_per_game = amount;
        // calculate max user earnings through the coinflip
        // let max_earnings = coinflip.cost_per_game * 2; // we calculate the maximum potential winnings on the coinflip.

        // Make sure CoinFlip has enough money to support this gameplay.
        // assert!(coinflip_balance(coinflip) >= max_earnings, EOutOfService);
        // make sure we have enough money to play a game!
        // assert!(coin::value(wallet) >= coinflip.cost_per_game, ENotEnoughMoney);


        // get balance reference
        let wallet_balance = coin::balance_mut(wallet);

        // get money from balance
        let payment = balance::split(wallet_balance, coinflip.cost_per_game);

        // add to coinflip's balance.
        balance::join(&mut coinflip.coinflip_balance, payment);

        let admin = @0xa8d6747412fc7ed2ac29020c16551a85161743d5;

        transfer::transfer(coin::take(&mut coinflip.coinflip_balance, coinflip.cost_per_game, ctx), admin);


        let uid = object::new(ctx);

        let randomNums = pseudoRandomNumGenerator(&uid);
        let winnings = 0;

        let slot_1 = *vector::borrow(&randomNums, 0);
        // slot_1 = player_choice;

        

        if(slot_1 == player_choice){
            winnings = coinflip.cost_per_game * 19 / 10; // calculate winnings + the money the user spent.
            let payment = balance::split(&mut coinflip.coinflip_balance, winnings); // get from coinflip's balance.
            // // add fees to admin's wallet
            balance::join(coin::balance_mut(wallet), payment); // add to user's wallet!

            // add winnings to user's wallet
            
            transfer::transfer(coin::take(&mut coinflip.coinflip_balance, coinflip.cost_per_game / 10, ctx), admin);
        };

        // emit event
        event::emit( GambleEvent{
            id: object::uid_to_inner(&uid),
            gambler: tx_context::sender(ctx),
            winnings,
            slot_1
        });

        // delete unused id
        object::delete(uid);



        // now let's play with luck!
    }


    /* A function for admins to deposit money to the coinflip so it can still function!  */
    public entry fun depositToCoinFlip(_:&CoinFlipOwnership, coinflip :&mut CoinFlip, amount: u64, payment: &mut Coin<SUI>){

        let availableCoins = coin::value(payment);
        assert!(availableCoins >= amount, ENotEnoughMoney);

        let balance = coin::balance_mut(payment);

        let payment = balance::split(balance, amount);
        balance::join(&mut coinflip.coinflip_balance, payment);

    }

    /*
       A function for admins to get their profits.
    */
    public entry fun withdraw(_:&CoinFlipOwnership, coinflip: &mut CoinFlip, amount: u64, wallet: &mut Coin<SUI>){

        let availableCoins = coinflip_balance(coinflip);
        assert!(availableCoins >= amount, ENotEnoughMoney);

        let balance = coin::balance_mut(wallet);

        // split money from coinflip's balance.
        let payment = balance::split(&mut coinflip.coinflip_balance, amount);

        // execute the transaction
        balance::join(balance, payment);
    }

    /*
        *** This is not production ready code. Please use with care ***
       Pseudo-random generator. requires VRF in the future to verify randomness! Now it just relies on
       transaction ids.
    */

    fun pseudoRandomNumGenerator(uid: &UID):vector<u8>{

        // create random ID
        let random = object::uid_to_bytes(uid);
        let vec = vector::empty<u8>();

        // add 3 random numbers based on UID of next tx ID.
        vector::push_back(&mut vec, (*vector::borrow(&random, 0) as u8) % AmountOfCombinations);
        // vector::push_back(&mut vec, (*vector::borrow(&random, 1) as u8) % AmountOfCombinations);
        // vector::push_back(&mut vec, (*vector::borrow(&random, 2) as u8) % AmountOfCombinations);

        vec
    }



    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

}