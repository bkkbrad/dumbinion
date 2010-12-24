//SVM_light can't be redistributed, so here is the kernel.h
//containing my code.
double custom_kernel(KERNEL_PARM *kernel_parm, SVECTOR *a, SVECTOR *b) 
{
  char a_string[1024];
  char b_string[1024];
  char *a_ctx;
  char *b_ctx;
  strcpy(a_string, a->userdefined);
  strcpy(b_string, b->userdefined);
  char* token_a = strtok_r(a_string, " ", &a_ctx);
  char* token_b = strtok_r(b_string, " ", &b_ctx);
 
  int num_equal = 0;
  while (token_a && token_b) {
    if (!strncmp(token_a, "buy:", 4) && !strncmp(token_b, "buy:", 4)) {
      int equal = !strcmp(token_a, token_b);
      //printf("buy tokens: %s, %s, Equal: %d\n", token_a, token_b, equal);
      if (!equal) {
        return 0;
      }
      token_a = strtok_r(NULL, " ", &a_ctx);
      token_b = strtok_r(NULL, " ", &b_ctx);
    } else {
      break;
    }
  }

  while (token_a && token_b) {
    int cmp = strcmp(token_a, token_b);
    if (cmp <= 0) {
      token_a = strtok_r(NULL, " ", &a_ctx);
    }
    if (cmp >= 0) {
      token_b = strtok_r(NULL, " ", &b_ctx);
    }
    if (cmp == 0) {
      num_equal++;
    }
  }
  
  if (strcmp(kernel_parm->custom, "subsets") == 0) {
    return pow(2, num_equal); 
  } else {
    return pow(num_equal, kernel_parm->poly_degree);
  } 
}
