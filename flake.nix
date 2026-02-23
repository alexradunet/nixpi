   {                                                                                                                                                                                                                            
     description = "Nixpi development environment";                                                                                                                                                                       
                                                                                                                                                                                                                                
     inputs = {                                                                                                                                                                                                                 
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";                                                                                                                                                                        
       flake-utils.url = "github:numtide/flake-utils";                                                                                                                                                                          
     };                                                                                                                                                                                                                   
                                                                                                                                                                                                                                
     outputs = { self, nixpkgs, flake-utils }:                                                                                                                                                                                  
       flake-utils.lib.eachDefaultSystem (system:                                                                                                                                                                               
         let                                                                                                                                                                                                                    
           pkgs = import nixpkgs { inherit system; };                                                                                                                                                                           
         in {                                                                                                                                                                                                                   
           devShells.default = pkgs.mkShell {                                                                                                                                                                                   
             packages = with pkgs; [                                                                                                                                                                                            
               git                                                                                                                                                                                                              
               nodejs_22                                                                                                                                                                                                        
               sqlite                                                                                                                                                                                                      sqlite                                                                                                                                                                                                           
               jq                                                                                                                                                                                                               
               ripgrep                                                                                                                                                                                                          
               fd                                                                                                                                                                                                               
             ];

             shellHook = ''
               export PS1="(nixpi-dev) $PS1"
             '';                                                                                                                                                                                                                    
           };                                                                                                                                                                                                                   
         });                                                                                                                                                                                                                    
   }      
