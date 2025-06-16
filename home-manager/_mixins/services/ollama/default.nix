{... }: {
  
  services.ollama = {
    acceleration = "rocm";
    enable = true;
  };
}	
