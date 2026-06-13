#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

char *gets();

void grant_access(void)
{
    puts("Access granted");
    exit(0);
}

int main(void)
{
    char admin_pin[64];
    char entered_pin[64];
    char *admin_pin_path;
    int fd;
    ssize_t bytes_read;
    const char *error_message;

    admin_pin_path = getenv("ADMIN_PIN_PATH");
    error_message = "ADMIN_PIN_PATH not set";
    if (!admin_pin_path) {
        goto fail;
    }

    fd = open(admin_pin_path, O_RDONLY);
    if (fd == -1) {
        error_message = "Failed to open admin pin file";
        goto fail;
    }

    bytes_read = read(fd, admin_pin, 32);
    error_message = "Failed to read admin pin file";
    if (bytes_read <= 0) {
        goto fail;
    }
    admin_pin[bytes_read] = '\0';

    gets(entered_pin);

    if (strcmp(entered_pin, admin_pin) == 0) {
        grant_access();
    }

    error_message = "Incorrect admin pin";

fail:
    fputs(error_message, stderr);
    return 1;
}
