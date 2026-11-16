import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

println("--> [Init-Script] Executing KnowLayer Jenkins post-startup initialization...")

def instance = Jenkins.getInstance()
def domain = Domain.global()
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// Ensure /var/run/docker.sock permissions for the jenkins user
try {
    def proc = "chmod 666 /var/run/docker.sock".execute()
    proc.waitFor()
    println("--> [Init-Script] /var/run/docker.sock permissions set successfully.")
} catch (Exception ex) {
    println("--> [Init-Script] Note: Could not adjust /var/run/docker.sock directly: ${ex.message}")
}

println("--> [Init-Script] Initialization complete.")
