package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func main() {

	if os.Args[1] != "clone-environment" {
		fmt.Println("Usage: clone-environment command")
		os.Exit(1)
	}

	baseEnvName := getUserInput("What is the route base environment?")
	newEnvName := getUserInput("What is the route of the new environment?")

	err := cloneEnvironment(baseEnvName, newEnvName)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Environment cloned successfully!")
}

func getUserInput(prompt string) string {
	fmt.Print(prompt + " ")
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	return scanner.Text()
}

func cloneEnvironment(baseEnvName, newEnvName string) error {
	baseEnvPath := filepath.Join(".", baseEnvName)
	newEnvPath := filepath.Join(".", newEnvName)

	// Check if the base environment exists
	if _, err := os.Stat(baseEnvPath); os.IsNotExist(err) {
		return fmt.Errorf("Base environment '%s' not found", baseEnvName)
	}

	// Check if the new environment already exists
	if _, err := os.Stat(newEnvPath); !os.IsNotExist(err) {
		fmt.Printf("Error: New environment '%s' already exists. Do you want to overwrite it? (y/n): ", newEnvName)
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Scan()
		response := strings.ToLower(scanner.Text())
		if response != "y" {
			fmt.Println("Cloning aborted.")
			return nil
		}

		// Remove existing directory and recreate it
		err := os.RemoveAll(newEnvPath)
		if err != nil {
			return fmt.Errorf("Error removing existing new environment directory: %v", err)
		}
	}

	// Create the new environment directory
	os.Mkdir(newEnvPath, os.ModePerm)
	// if err != nil {
	// 	return fmt.Errorf("Error creating new environment directory: %v", err)
	// }

	baseEnvArr := strings.Split(baseEnvPath, "/")
	mewEnvArr := strings.Split(newEnvPath, "/")
	oldName := baseEnvArr[len(baseEnvArr)-1]
	newName := mewEnvArr[len(mewEnvArr)-1]

	// Copy all content from base environment to new environment
	err := copyDir(baseEnvPath, newEnvPath, oldName, newName)
	if err != nil {
		return fmt.Errorf("Error copying content from base environment to new environment: %v", err)
	}


	return nil
}

func copyDir(src, dst, oldName, newName string) error {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}

	if !srcInfo.IsDir() {
		return fmt.Errorf("source is not a directory")
	}

	_, err = os.Stat(dst)
	if os.IsNotExist(err) {
		err := os.MkdirAll(dst, os.ModePerm)
		if err != nil {
			return err
		}
	} else if err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if entry.Name() == ".terragrunt-cache" || entry.Name() == ".terraform.lock.hcl" {
			// Skip the folder you want to exclude
			continue
		}

		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())

		if strings.Contains(dstPath, oldName) {
			dstPath = strings.Replace(dstPath, oldName, newName, -1)
		}

		if entry.IsDir() {
			// Check if the directory does not exist in the destination
			_, err := os.Stat(dstPath)
			if os.IsNotExist(err) {
				err := copyDir(srcPath, dstPath, oldName, newName)
				if err != nil {
					return err
				}
			}
		} else {
			err := copyFile(srcPath, dstPath)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

func copyFile(src, dst string) error {
	source, err := os.Open(src)
	if err != nil {
		return err
	}
	defer source.Close()

	destination, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destination.Close()

	_, err = io.Copy(destination, source)
	if err != nil {
		return err
	}

	return nil
}
